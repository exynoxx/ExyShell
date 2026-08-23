using GLib;

/* Win+P display-mode switching. Reads the live output layout straight from the
 * compositor over wlr-output-management-v1 (in-process, via wlhooks — the same
 * client lumen-settings and lumen-session use), classifies outputs as internal
 * vs external, and applies one of three modes in a single atomic configuration.
 *
 * This is a transient/live toggle: it does NOT rewrite ~/.config/wayfire.ini
 * [output:*] sections, so it never fights the persistent layout owned by the
 * lumen-settings display page.
 *
 * We are a short-lived CLI, so every Wayland step here is synchronous:
 * output_mgmt_init drains the initial head/mode burst before returning and
 * config_apply blocks until the compositor answers succeeded/failed. There is
 * no main loop and none is needed. */
public class DisplayCtl {

    public enum Mode {
        INTERNAL_ONLY,
        EXTEND,
        EXTERNAL_ONLY;

        public string label() {
            switch (this) {
                case INTERNAL_ONLY: return "Built-in display";
                case EXTERNAL_ONLY: return "External display";
                default:            return "Extend";
            }
        }
        // Symbolic icons, all shipped by Adwaita.
        public string icon() {
            switch (this) {
                case INTERNAL_ONLY: return "video-single-display-symbolic";
                case EXTERNAL_ONLY: return "video-display-symbolic";
                default:            return "video-joined-displays-symbolic";
            }
        }
        /* key()/parse() are inverses and are the cross-process contract: the
         * lumen-osd picker spells a mode with key(), lumen-osdctl reads it back
         * with parse(). Keep them in step. */
        public string key() {
            switch (this) {
                case INTERNAL_ONLY: return "internal";
                case EXTERNAL_ONLY: return "external";
                default:            return "extend";
            }
        }
        public static Mode? parse(string s) {
            switch (s.down()) {
                case "internal": return INTERNAL_ONLY;
                case "extend":   return EXTEND;
                case "external": return EXTERNAL_ONLY;
                default:         return null;
            }
        }
    }

    /* One available mode of a head. Refresh is kept in the protocol's own
     * millihertz integers — no float, so no locale decimal separator anywhere. */
    private class HeadMode {
        public int  width;
        public int  height;
        public int  refresh_mhz;
        public bool preferred;
    }

    /* Live state of one connected head. */
    private class Head {
        public int    idx;
        public string name;         // connector, e.g. "eDP-1"
        public string identity;     // EDID-based key (DisplayProfileStore)
        public bool   enabled;
        public int    pos_x;
        public int    pos_y;
        public int    transform;
        public GenericArray<HeadMode> modes = new GenericArray<HeadMode>();
        public HeadMode? current_mode;

        // Laptop panels: eDP / LVDS / DSI. Everything else (HDMI/DP/DVI/…) external.
        public bool is_internal() {
            string u = name.up();
            return u.has_prefix("EDP") || u.has_prefix("LVDS") || u.has_prefix("DSI");
        }

        public HeadMode? pick_mode() {
            if (current_mode != null) return current_mode;
            for (int i = 0; i < modes.length; i++)
                if (modes.get(i).preferred) return modes.get(i);
            return modes.length > 0 ? modes.get(0) : null;
        }

        // On-screen width of `m` under this head's transform (90/270 swap axes),
        // so the left-to-right layout below doesn't overlap a rotated monitor.
        public int width_on_screen(HeadMode m) {
            bool portrait = (transform % 2) != 0;
            return portrait ? m.height : m.width;
        }
    }

    // Owned for the lifetime of the process: the vapi frees a Wl.Display with
    // wl_display_disconnect when it goes out of scope, which would tear the
    // protocol out from under wlhooks.
    private static Wl.Display? wl = null;
    private static bool tried_init = false;

    private static bool ensure_init() {
        if (tried_init) return WLHooks.output_mgmt_available();
        tried_init = true;

        // Mirror wl_display_connect(NULL): honour $WAYLAND_DISPLAY, else "wayland-0".
        string sock = Environment.get_variable("WAYLAND_DISPLAY") ?? "wayland-0";
        wl = new Wl.Display.connect(sock);
        if (wl == null) {
            warning("cannot connect to Wayland display '%s' (not running under Wayfire?)", sock);
            return false;
        }
        if (WLHooks.output_mgmt_init((!) wl) != 0 || !WLHooks.output_mgmt_available()) {
            warning("compositor lacks wlr-output-management-v1");
            return false;
        }
        return true;
    }

    private static GenericArray<Head> enumerate() {
        var heads = new GenericArray<Head>();
        if (!ensure_init()) return heads;
        WLHooks.output_mgmt_refresh();

        var by_name = new HashTable<string, Head>(str_hash, str_equal);
        WLHooks.output_mgmt_for_each_head((idx, name, desc, enabled, x, y, transform, scale) => {
            var h = new Head();
            h.idx = idx;
            h.name = name;
            h.identity = DisplayProfileStore.identity_for("", "", "", desc, name);
            h.enabled = enabled;
            h.pos_x = x; h.pos_y = y;
            h.transform = transform;
            heads.add(h);
            by_name.set(name, h);
        });

        // EDID identity comes from a separate replay; matching by connector name
        // is exact (heads are unique per connector).
        WLHooks.output_mgmt_for_each_head_identity((idx, name, make, model, serial, desc) => {
            var h = by_name.get(name);
            if (h != null) h.identity =
                DisplayProfileStore.identity_for(make, model, serial, desc, name);
        });

        for (int i = 0; i < heads.length; i++) {
            var h = heads.get(i);
            WLHooks.output_mgmt_for_each_mode(h.idx, (hidx, w, ht, mhz, preferred, current) => {
                var m = new HeadMode();
                m.width = w; m.height = ht; m.refresh_mhz = mhz; m.preferred = preferred;
                h.modes.add(m);
                if (current) h.current_mode = m;
            });
        }
        return heads;
    }

    private static bool has_internal(GenericArray<Head> heads) {
        for (int i = 0; i < heads.length; i++)
            if (heads.get(i).is_internal()) return true;
        return false;
    }
    private static bool has_external(GenericArray<Head> heads) {
        for (int i = 0; i < heads.length; i++)
            if (!heads.get(i).is_internal()) return true;
        return false;
    }

    private static Mode current_state(GenericArray<Head> heads) {
        bool internal_on = false, external_on = false;
        for (int i = 0; i < heads.length; i++) {
            var h = heads.get(i);
            if (!h.enabled) continue;
            if (h.is_internal()) internal_on = true;
            else external_on = true;
        }
        if (internal_on && !external_on) return Mode.INTERNAL_ONLY;
        if (external_on && !internal_on) return Mode.EXTERNAL_ONLY;
        return Mode.EXTEND;   // both on (or, defensively, none)
    }

    // Never produce a layout that blanks every screen.
    private static Mode resolve(GenericArray<Head> heads, Mode mode) {
        if (mode == Mode.INTERNAL_ONLY && !has_internal(heads)) return Mode.EXTERNAL_ONLY;
        if (mode == Mode.EXTERNAL_ONLY && !has_external(heads)) return Mode.INTERNAL_ONLY;
        return mode;
    }

    /* ---- Remembered EXTEND arrangement ---------------------------------- *
     * The canned builder below lays heads left-to-right at y=0 — fine the first
     * time, but it would clobber any custom extended arrangement (a monitor
     * placed left of the laptop, stacked vertically, a non-default resolution,
     * …). So whenever we observe a live EXTEND state we snapshot it into the
     * SHARED display-profile store — the same file lumen-settings writes on
     * "Keep" and lumen-session restores on hotplug — and read it back when the
     * user cycles to EXTEND. One layout memory, keyed by EDID identity set. */

    // Only an EXTEND state is worth remembering: saving an internal-only or
    // external-only snapshot would make lumen-session restore *that* on every
    // hotplug of this monitor set.
    private static void maybe_save_extend(GenericArray<Head> heads) {
        if (current_state(heads) != Mode.EXTEND) return;

        var prof = new DisplayProfile();
        for (int i = 0; i < heads.length; i++) {
            var h = heads.get(i);
            var m = h.current_mode;
            var st = new DisplayOutputState();
            st.enabled     = h.enabled;
            st.width       = m != null ? m.width : 0;
            st.height      = m != null ? m.height : 0;
            st.refresh_mhz = m != null ? m.refresh_mhz : 0;
            st.x           = h.pos_x;
            st.y           = h.pos_y;
            st.transform   = h.transform;
            prof.outputs.add(h.identity);
            prof.states.set(h.identity, st);
        }
        DisplayProfileStore.save_or_update(prof);
    }

    // The saved layout for the connected set, but only when it puts every
    // connected head on — a profile that disables one is not an EXTEND layout,
    // so we fall back to the canned builder instead.
    private static DisplayProfile? extend_profile(GenericArray<Head> heads) {
        var keys = new GenericArray<string>();
        for (int i = 0; i < heads.length; i++) keys.add(heads.get(i).identity);

        var prof = DisplayProfileStore.match(keys);
        if (prof == null) return null;

        for (int i = 0; i < heads.length; i++) {
            var st = prof.states.get(heads.get(i).identity);
            if (st == null || !st.enabled || st.width <= 0 || st.height <= 0) return null;
        }
        return prof;
    }

    // Build one atomic configuration for `mode` and apply it.
    private static bool build_and_apply(GenericArray<Head> heads, Mode mode) {
        DisplayProfile? saved = (mode == Mode.EXTEND) ? extend_profile(heads) : null;

        // Deterministic placement order: internal first, then externals.
        var ordered = new GenericArray<Head>();
        for (int i = 0; i < heads.length; i++)
            if (heads.get(i).is_internal()) ordered.add(heads.get(i));
        for (int i = 0; i < heads.length; i++)
            if (!heads.get(i).is_internal()) ordered.add(heads.get(i));

        if (!config_begin()) return false;

        int enabled_count = 0;
        int x = 0;
        for (int i = 0; i < ordered.length; i++) {
            var h = ordered.get(i);
            bool on;
            switch (mode) {
                case Mode.INTERNAL_ONLY: on =  h.is_internal(); break;
                case Mode.EXTERNAL_ONLY: on = !h.is_internal(); break;
                default:                 on =  true;            break;   // EXTEND
            }
            if (!on) {
                WLHooks.output_mgmt_config_disable(h.name);
                continue;
            }

            var st = (saved != null) ? saved.states.get(h.identity) : null;
            if (st != null) {
                WLHooks.output_mgmt_config_enable(h.name, st.width, st.height,
                    st.refresh_mhz, st.x, st.y, st.transform);
                enabled_count++;
                continue;
            }

            var m = h.pick_mode();
            if (m == null) {
                WLHooks.output_mgmt_config_disable(h.name);
                continue;
            }
            WLHooks.output_mgmt_config_enable(h.name, m.width, m.height,
                m.refresh_mhz, x, 0, h.transform);
            x += h.width_on_screen(m);
            enabled_count++;
        }

        // Never blank every screen: abandon the configuration rather than apply
        // it (the next config_begin frees the dangling configuration object).
        if (enabled_count == 0) {
            warning("refusing to apply a layout that enables no output");
            return false;
        }

        int rc = WLHooks.output_mgmt_config_apply();
        if (rc != 0) {
            warning("output configuration rejected by the compositor (rc=%d)", rc);
            return false;
        }
        return true;
    }

    // The serial only exists once a manager `done` has arrived; drain once and
    // retry if it hasn't yet.
    private static bool config_begin() {
        if (WLHooks.output_mgmt_config_begin() == 0) return true;
        WLHooks.output_mgmt_refresh();
        if (WLHooks.output_mgmt_config_begin() == 0) return true;
        warning("no output-configuration serial available");
        return false;
    }

    // Apply a specific mode. Returns the mode actually applied (after guards),
    // or null on failure / no outputs.
    public static Mode? apply(Mode requested) {
        var heads = enumerate();
        if (heads.length == 0) {
            warning("no outputs reported (not running under Wayfire?)");
            return null;
        }
        // Snapshot the arrangement before we change it, so a later return to
        // EXTEND can restore whatever the user had set up.
        maybe_save_extend(heads);
        var mode = resolve(heads, requested);
        if (!build_and_apply(heads, mode)) return null;
        return mode;
    }

    // The mode the live layout currently represents (used to seed the Win+P
    // picker highlight). null if no outputs are visible.
    public static Mode? current() {
        var heads = enumerate();
        if (heads.length == 0) return null;
        // The picker queries this when it opens — the ideal moment to capture a
        // live extended arrangement before the user starts cycling away from it.
        maybe_save_extend(heads);
        return current_state(heads);
    }

    // Advance to the next mode: INTERNAL_ONLY → EXTEND → EXTERNAL_ONLY → …
    // With no external display connected, stays on INTERNAL_ONLY.
    public static Mode? cycle() {
        var heads = enumerate();
        if (heads.length == 0) {
            warning("no outputs reported (not running under Wayfire?)");
            return null;
        }
        maybe_save_extend(heads);
        Mode next;
        if (!has_external(heads)) {
            next = Mode.INTERNAL_ONLY;
        } else if (!has_internal(heads)) {
            next = Mode.EXTERNAL_ONLY;   // only externals — nothing to cycle to
        } else {
            switch (current_state(heads)) {
                case Mode.INTERNAL_ONLY: next = Mode.EXTEND;        break;
                case Mode.EXTEND:        next = Mode.EXTERNAL_ONLY; break;
                default:                 next = Mode.INTERNAL_ONLY; break;
            }
        }
        if (!build_and_apply(heads, next)) return null;
        return next;
    }
}
