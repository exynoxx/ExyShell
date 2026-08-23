using GLib;

/**
 * Outcome of a connection attempt — lets the UI distinguish a wrong
 * passphrase (worth re-prompting) from a generic failure.
 */
public enum WifiConnectResult {
    SUCCESS,
    BAD_PASSWORD,
    FAILED
}

public class WifiNet : GLib.Object {
    public string ssid;
    public int    signal;
    public string security;
    public bool   is_saved;   // a NetworkManager profile already exists for this SSID

    public WifiNet(string ssid, int signal, string security, bool is_saved = false) {
        this.ssid     = ssid;
        this.signal   = signal;
        this.security = security;
        this.is_saved = is_saved;
    }

    /** True when the network advertises some form of encryption. */
    public bool is_secured() {
        return security != "" && security != "--";
    }
}

/**
 * Per-device network details (IP configuration, link identity), as reported by
 * `nmcli device show`. Empty strings for fields NetworkManager doesn't report.
 */
public class NetDetails : GLib.Object {
    public string   ip4      = "";
    public string   gateway  = "";
    public string[] dns      = {};
    public string   ip6      = "";
    public string   mac      = "";
    public string   security = "";
    public string   band     = "";
    public string   password = "";
}

public class NmcliClient : GLib.Object {

    /**
     * Split an nmcli terse-format line on ':' with backslash-escape support.
     * Stops splitting after max_fields fields (-1 = unlimited).
     */
    private string[] split_terse(string line, int max_fields = -1) {
        string[] parts = {};
        var sb = new GLib.StringBuilder();
        bool escaped = false;
        int split_count = 0;

        for (int i = 0; i < line.length; i++) {
            char c = line[i];

            if (escaped) {
                sb.append_c(c);
                escaped = false;
                continue;
            }

            if (c == '\\') {
                escaped = true;
                continue;
            }

            if (c == ':' && (max_fields < 0 || split_count < max_fields - 1)) {
                parts += sb.str;
                sb.truncate(0);
                split_count++;
                continue;
            }

            sb.append_c(c);
        }

        if (escaped) sb.append_c('\\');
        parts += sb.str;
        return parts;
    }

    private class DevRow : GLib.Object {
        public string device;
        public string dev_type;
        public string state;
        public string connection;
    }

    private GLib.Mutex              table_lock  = GLib.Mutex();
    private GenericArray<DevRow>?   table_cache = null;
    private int64                   table_us    = 0;

    // WifiService asks all four device questions back-to-back on every poll, so
    // the one `nmcli device` listing they share is cached briefly — one spawn
    // per poll instead of four. The TTL is far shorter than the 4 s poll, so a
    // state change is never held for more than one pass.
    private const int64 TABLE_TTL_US = 1000000;

    private GenericArray<DevRow> device_table() {
        table_lock.lock();
        var cached = table_cache;
        bool fresh = cached != null && GLib.get_monotonic_time() - table_us < TABLE_TTL_US;
        table_lock.unlock();
        if (fresh) return cached;

        var rows = new GenericArray<DevRow>();
        string? out_str = LumenCommon.Proc.run_capture(new string[]{
            "nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"
        });
        if (out_str != null) {
            foreach (var line in out_str.split("\n")) {
                var p = split_terse(line, 4);
                if (p.length < 4) continue;
                var r = new DevRow();
                r.device     = p[0];
                r.dev_type   = p[1];
                r.state      = p[2];
                r.connection = p[3];
                rows.add(r);
            }
        }

        table_lock.lock();
        table_cache = rows;
        table_us    = GLib.get_monotonic_time();
        table_lock.unlock();
        return rows;
    }

    public string query_connected() {
        foreach (var r in device_table())
            if (r.dev_type == "wifi" && r.state == "connected") return r.connection;
        return "";
    }

    public bool query_ethernet_connected() {
        foreach (var r in device_table())
            if (r.dev_type == "ethernet" && r.state == "connected") return true;
        return false;
    }

    public string get_wifi_device() {
        foreach (var r in device_table())
            if (r.dev_type == "wifi") return r.device;
        return "";
    }

    public string get_ethernet_device() {
        foreach (var r in device_table())
            if (r.dev_type == "ethernet") return r.device;
        return "";
    }

    /**
     * BLOCKING — call from a background thread. Reads a device's IP config and
     * link identity via `nmcli device show`, parsing the terse KEY:VALUE lines
     * (indexed keys like IP4.ADDRESS[1] / IP4.DNS[1]). Missing fields stay "".
     */
    public NetDetails device_details(string dev) {
        var d = new NetDetails();
        if (dev == "") return d;

        string? out_str = LumenCommon.Proc.run_capture(new string[]{
            "nmcli", "-t", "-f",
            "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,GENERAL.HWADDR,GENERAL.CONNECTION",
            "device", "show", dev
        });
        if (out_str == null) return d;

        string[] dns = {};
        foreach (var line in out_str.split("\n")) {
            var p = split_terse(line, 2);
            if (p.length < 2) continue;
            string key = p[0].strip();
            string val = p[1].strip();
            if (val == "" || val == "--") continue;

            // Strip the [n] index suffix so IP4.ADDRESS[1] matches IP4.ADDRESS.
            int br = key.index_of_char('[');
            string bare = br >= 0 ? key.substring(0, br) : key;

            if (bare == "IP4.ADDRESS" && d.ip4 == "") d.ip4 = val;
            else if (bare == "IP4.GATEWAY")           d.gateway = val;
            else if (bare == "IP4.DNS")               dns += val;
            else if (bare == "IP6.ADDRESS" && d.ip6 == "") d.ip6 = val;
            else if (bare == "GENERAL.HWADDR")        d.mac = val;
        }
        d.dns = dns;
        return d;
    }

    /**
     * BLOCKING — call from a background thread. Reads the security type and RF
     * band of the currently associated access point from the scan list (the
     * IN-USE `*` row). `nmcli device show` reports neither, so the band is
     * derived from the AP's frequency: sub-3 GHz ⇒ 2.4, sub-5.925 GHz ⇒ 5,
     * else 6. Both stay "" when nothing is connected.
     */
    public void active_ap(out string security, out string band) {
        security = "";
        band     = "";

        string? out_str = LumenCommon.Proc.run_capture(new string[]{
            "nmcli", "-t", "-f", "IN-USE,FREQ,SECURITY", "device", "wifi", "list"
        });
        if (out_str == null) return;

        foreach (var line in out_str.split("\n")) {
            var p = split_terse(line, 3);
            if (p.length < 3 || p[0].strip() != "*") continue;

            security = p[2].strip();

            // FREQ arrives as e.g. "5640 MHz"; take the leading integer.
            int mhz = 0;
            if (int.try_parse(p[1].strip().split(" ")[0], out mhz) && mhz > 0) {
                if      (mhz < 3000) band = "2.4 GHz";
                else if (mhz < 5925) band = "5 GHz";
                else                 band = "6 GHz";
            }
            return;
        }
    }

    /**
     * BLOCKING — call from a background thread. Returns the saved passphrase for
     * a connection profile (`nmcli -s -g …psk`), or "" when the profile has no
     * PSK (open/enterprise network) or the secret can't be read. `-s` is
     * required for nmcli to emit secrets at all.
     */
    public string connection_psk(string name) {
        if (name == "") return "";
        string? out_str = LumenCommon.Proc.run_capture(new string[]{
            "nmcli", "-s", "-g", "802-11-wireless-security.psk",
            "connection", "show", "id", name
        });
        if (out_str == null) return "";
        return out_str.strip();
    }

    public bool query_enabled() {
        string? out_str = LumenCommon.Proc.run_capture(new string[]{ "nmcli", "radio", "wifi" });
        if (out_str == null) return false;
        return out_str.strip() == "enabled";
    }

    /**
     * Blocking — call from a background thread. rfkill unblock clears any
     * hard/soft block first, otherwise `nmcli radio wifi on` can no-op.
     */
    public void set_enabled(bool on) {
        if (on) LumenCommon.Proc.run_capture(new string[] { "rfkill", "unblock", "wifi" });
        LumenCommon.Proc.run_capture(new string[] { "nmcli", "radio", "wifi", on ? "on" : "off" });
    }

    /** Fire-and-forget: ask NetworkManager to re-probe the air. */
    public void rescan() {
        LumenCommon.Proc.spawn_detached(new string[] { "nmcli", "device", "wifi", "rescan" });
    }

    /**
     * Connect to an SSID, blocking until nmcli finishes so the caller can
     * report success/failure. With from_saved, brings up the existing profile
     * (`connection up`, no passphrase needed); otherwise associates via
     * `device wifi connect`, passing the passphrase when one was given (open
     * networks pass none). Call from a background thread — this can block for
     * several seconds while NetworkManager negotiates the association.
     */
    public WifiConnectResult connect(string ssid, string password, bool from_saved) {
        if (from_saved)
            return run_connect(new string[] { "nmcli", "connection", "up", "id", ssid });
        if (password == "")
            return run_connect(new string[] { "nmcli", "device", "wifi", "connect", ssid });
        return run_connect(new string[] {
            "nmcli", "device", "wifi", "connect", ssid, "password", password
        });
    }

    /**
     * Connect to a hidden SSID (not present in scan results). Mirrors connect()
     * but adds `hidden yes` so NetworkManager probes the SSID directly. Blocking
     * — call from a background thread.
     */
    public WifiConnectResult connect_hidden(string ssid, string password) {
        if (password == "")
            return run_connect(new string[] {
                "nmcli", "device", "wifi", "connect", ssid, "hidden", "yes"
            });
        return run_connect(new string[] {
            "nmcli", "device", "wifi", "connect", ssid, "password", password, "hidden", "yes"
        });
    }

    /**
     * Run one nmcli connect variant to completion and classify the outcome.
     *
     * NOTE: the passphrase is an argv element, so it is readable in
     * /proc/<pid>/cmdline for the duration of the association. `nmcli device
     * wifi connect` offers no passwd-file option (only `connection up` does),
     * and `--ask` reads its prompts from stdin but gives no guarantee about
     * which prompt a piped line answers, so there is no reliable stdin route
     * for the create-and-activate path.
     */
    private WifiConnectResult run_connect(string[] argv) {
        string std_out = "", std_err = "";
        int status = -1;
        try {
            Process.spawn_sync(null, argv, null, SpawnFlags.SEARCH_PATH,
                null, out std_out, out std_err, out status);
        } catch (SpawnError e) {
            return WifiConnectResult.FAILED;
        }

        bool ok = false;
        try { ok = Process.check_wait_status(status); } catch (Error e) { ok = false; }
        if (ok) return WifiConnectResult.SUCCESS;

        // NetworkManager reports a rejected passphrase a few different ways
        // depending on version; treat any secrets/auth wording as bad password
        // so the UI can re-prompt instead of showing a dead-end failure.
        string err = (std_err + " " + std_out).down();
        if (err.contains("secrets were required")
            || err.contains("no secrets")
            || err.contains("802-11-wireless-security")
            || err.contains("802.1x")
            || err.contains("authentication")
            || err.contains("password"))
            return WifiConnectResult.BAD_PASSWORD;
        return WifiConnectResult.FAILED;
    }

    /** Resolves the ethernet device (blocking), then brings it up or down. */
    public void set_ethernet_enabled(bool on) {
        string dev = get_ethernet_device();
        if (dev == "") return;
        LumenCommon.Proc.spawn_detached(new string[] {
            "nmcli", "device", on ? "connect" : "disconnect", dev
        });
    }

    /**
     * SSIDs that already have a saved NetworkManager profile. These can be
     * re-joined without re-entering a passphrase, and NetworkManager will
     * auto-connect to them on its own at login / when in range.
     */
    public Gee.HashSet<string> saved_ssids() {
        var saved = new Gee.HashSet<string>();
        string? out_str = LumenCommon.Proc.run_capture(new string[]{
            "nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"
        });
        if (out_str == null) return saved;

        foreach (var line in out_str.split("\n")) {
            var p = split_terse(line, 2);
            if (p.length >= 2 && p[1] == "802-11-wireless" && p[0].strip() != "")
                saved.add(p[0].strip());
        }
        return saved;
    }

    public void disconnect() {
        string dev = get_wifi_device();
        if (dev == "") return;
        LumenCommon.Proc.spawn_detached(new string[] { "nmcli", "device", "disconnect", dev });
    }

    /** Delete the saved profile for an SSID (`nmcli connection delete id <ssid>`). */
    public void forget(string ssid) {
        LumenCommon.Proc.spawn_detached(new string[] { "nmcli", "connection", "delete", "id", ssid });
    }

    public WifiNet[] fetch_nets() {
        string? out_str = LumenCommon.Proc.run_capture(new string[]{
            "nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "device", "wifi", "list"
        });
        if (out_str == null) return {};

        var saved = saved_ssids();
        WifiNet[] result = {};
        var seen = new GLib.HashTable<string, bool>(str_hash, str_equal);

        foreach (var line in out_str.split("\n")) {
            var p = split_terse(line, 3);
            if (p.length < 3) continue;
            string ssid = p[0].strip();
            if (ssid == "" || ssid == "--") continue;
            if (seen.contains(ssid)) continue;
            seen.insert(ssid, true);
            int signal = 0;
            if (!int.try_parse(p[1], out signal)) continue;
            result += new WifiNet(ssid, signal, p[2], saved.contains(ssid));
        }
        return result;
    }
}
