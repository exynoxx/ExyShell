using GLib;

public class BtDevice : GLib.Object {
    public string mac;        // AA:BB:CC:DD:EE:FF
    public string name;       // friendly name (falls back to mac)
    public string dev_icon;   // bluez "Icon:" field — audio-card, input-mouse, phone, …
    public bool   paired;
    public bool   connected;

    public BtDevice(string mac, string name, string dev_icon, bool paired, bool connected) {
        this.mac       = mac;
        this.name      = name;
        this.dev_icon  = dev_icon;
        this.paired    = paired;
        this.connected = connected;
    }
}

/**
 * Extended per-device info from `bluetoothctl info` — everything BtDevice holds
 * plus pairing/trust/battery detail for the settings device-detail expansion.
 */
public class BtDeviceDetails : GLib.Object {
    public string mac          = "";
    public string name         = "";
    public string dev_icon     = "";
    public string address_type = "";
    public bool   paired       = false;
    public bool   bonded       = false;
    public bool   trusted      = false;
    public bool   connected    = false;
    public int    battery      = -1;   // -1 when absent
    public string rssi         = "";
}

/**
 * bluetoothctl accepts one-shot subcommands non-interactively, so reads use
 * LumenCommon.Proc.run_capture (blocking) and fire-and-forget actions use
 * LumenCommon.Proc.spawn_detached.
 */
public class BtctlClient : GLib.Object {

    private string field_value(string line) {
        int idx = line.index_of_char(':');
        if (idx < 0) return "";
        return line.substring(idx + 1).strip();
    }

    public bool query_powered() {
        string? out_str = LumenCommon.Proc.run_capture(new string[]{ "bluetoothctl", "show" });
        if (out_str == null) return false;

        foreach (var line in out_str.split("\n")) {
            var t = line.strip();
            if (t.has_prefix("Powered:")) return field_value(t) == "yes";
        }
        return false;
    }

    public BtDevice[] fetch_devices() {
        string? out_str = LumenCommon.Proc.run_capture(new string[]{ "bluetoothctl", "devices" });
        if (out_str == null) return {};

        BtDevice[] result = {};
        var seen = new GLib.HashTable<string, bool>(str_hash, str_equal);

        foreach (var line in out_str.split("\n")) {
            // "Device AA:BB:CC:DD:EE:FF Friendly Name"
            var t = line.strip();
            if (!t.has_prefix("Device ")) continue;
            string rest = t.substring(7).strip();
            int sp = rest.index_of_char(' ');
            string mac  = sp < 0 ? rest : rest.substring(0, sp);
            if (mac == "" || seen.contains(mac)) continue;
            seen.insert(mac, true);
            result += info(mac);
        }
        return result;
    }

    public BtDevice info(string mac) {
        string? out_str = LumenCommon.Proc.run_capture(new string[]{ "bluetoothctl", "info", mac });
        if (out_str == null) return new BtDevice(mac, mac, "", false, false);

        string name      = mac;
        string dev_icon  = "";
        bool   paired    = false;
        bool   connected = false;

        foreach (var line in out_str.split("\n")) {
            var t = line.strip();
            if      (t.has_prefix("Name:"))      name      = field_value(t);
            else if (t.has_prefix("Icon:"))      dev_icon  = field_value(t);
            else if (t.has_prefix("Paired:"))    paired    = field_value(t) == "yes";
            else if (t.has_prefix("Connected:")) connected = field_value(t) == "yes";
        }
        if (name == "") name = mac;
        return new BtDevice(mac, name, dev_icon, paired, connected);
    }

    /**
     * Full parse of `bluetoothctl info <mac>` — same command as info() but also
     * reads AddressType/Bonded/Trusted/RSSI and the Battery Percentage line
     * ("Battery Percentage: 0x64 (100)" → 100). Blocking; call off the main loop.
     */
    public BtDeviceDetails device_details(string mac) {
        var d = new BtDeviceDetails();
        d.mac  = mac;
        d.name = mac;

        string? out_str = LumenCommon.Proc.run_capture(new string[]{ "bluetoothctl", "info", mac });
        if (out_str == null) return d;

        foreach (var line in out_str.split("\n")) {
            var t = line.strip();
            if      (t.has_prefix("Name:"))         d.name         = field_value(t);
            else if (t.has_prefix("Icon:"))         d.dev_icon     = field_value(t);
            else if (t.has_prefix("AddressType:"))  d.address_type = field_value(t);
            else if (t.has_prefix("Paired:"))       d.paired       = field_value(t) == "yes";
            else if (t.has_prefix("Bonded:"))       d.bonded       = field_value(t) == "yes";
            else if (t.has_prefix("Trusted:"))      d.trusted      = field_value(t) == "yes";
            else if (t.has_prefix("Connected:"))    d.connected    = field_value(t) == "yes";
            else if (t.has_prefix("RSSI:"))         d.rssi         = field_value(t);
            else if (t.has_prefix("Battery Percentage:")) {
                // "0x64 (100)" — take the parenthesized decimal.
                var v = field_value(t);
                int lp = v.index_of_char('(');
                int rp = v.index_of_char(')');
                if (lp >= 0 && rp > lp) {
                    int pct = 0;
                    if (int.try_parse(v.substring(lp + 1, rp - lp - 1).strip(), out pct))
                        d.battery = pct;
                }
            }
        }
        if (d.name == "") d.name = mac;
        return d;
    }

    public void scan(uint secs) {
        LumenCommon.Proc.run_capture(new string[]{
            "bluetoothctl", "--timeout", "%u".printf(secs), "scan", "on"
        });
    }

    /**
     * Power the controller on or off. Powering on first clears any rfkill
     * soft-block, otherwise `bluetoothctl power on` fails with off-blocked.
     * Blocking sequence — call from a background thread.
     */
    public void set_powered(bool on) {
        if (on) {
            LumenCommon.Proc.run_capture(new string[] { "rfkill", "unblock", "bluetooth" });
            LumenCommon.Proc.run_capture(new string[] { "bluetoothctl", "power", "on" });
        } else {
            LumenCommon.Proc.run_capture(new string[] { "bluetoothctl", "power", "off" });
        }
    }

    public void connect(string mac) {
        LumenCommon.Proc.spawn_detached(new string[] { "bluetoothctl", "connect", mac });
    }

    public void disconnect(string mac) {
        LumenCommon.Proc.spawn_detached(new string[] { "bluetoothctl", "disconnect", mac });
    }

    /**
     * Pair → trust → connect, run synchronously in order. Best-effort
     * "just works" pairing; interactive passkey/PIN confirmation is not
     * handled. Call from a background thread — each step blocks.
     */
    public void pair(string mac) {
        LumenCommon.Proc.run_capture(new string[] { "bluetoothctl", "pair",    mac });
        LumenCommon.Proc.run_capture(new string[] { "bluetoothctl", "trust",   mac });
        LumenCommon.Proc.run_capture(new string[] { "bluetoothctl", "connect", mac });
    }

    public void remove(string mac) {
        LumenCommon.Proc.spawn_detached(new string[] { "bluetoothctl", "remove", mac });
    }
}
