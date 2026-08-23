using GLib;

// Global panel placement, read once at startup from panel.json (flat dotted
// keys, written by lumen-settings). Widgets that must mirror their layout when
// the panel sits at the top of the screen (popover direction, tray growth, the
// backdrop strip's edge) consult PanelConfig.at_top rather than threading the
// flag through every constructor.
public class PanelConfig {
    public static bool at_top = false;

    // How a taskbar entry signals it has open windows but isn't focused, so a
    // running app is distinguishable from a pinned-but-closed one. Read once at
    // startup; AppEntry.snapshot() branches on it. SHADE is the default.
    public enum OpenIndicator { SHADE, DOT, CORNERS, GLASS, ROUND, NONE }
    public static OpenIndicator open_indicator = OpenIndicator.SHADE;

    // How the focused (active) taskbar entry is marked. UNDERLINE is the
    // original accent bar under the icon; RING draws an accent ring around it;
    // SUNSHINE radiates triangular rays around it; GLASS is a navy frosted disc
    // behind it; CIRCLE is the ROUND open-glass white sheen, but fainter. Read
    // once at startup; AppEntry resolves it to a draw routine at construction.
    public enum ActiveIndicator { UNDERLINE, RING, SUNSHINE, GLASS, CIRCLE }
    public static ActiveIndicator active_indicator = ActiveIndicator.UNDERLINE;

    // Multi-monitor: when true a panel is placed on every connected output.
    // per_monitor_apps (a sub-option) makes each panel's taskbar show only the
    // windows on its own monitor.
    public static bool multi_monitor = false;
    public static bool per_monitor_apps = false;
    // When true (and multi_monitor is on) every secondary panel also shows the
    // tray area — minus the system-tray (SNI) icons, which stay on the host.
    public static bool tray_all_monitors = false;

    // When true a persistent launcher button (app glyph) sits at the left edge
    // of the panel; clicking it toggles the app-drawer reveal (curtain/slide
    // peek). Only effective in a PANEL_PEEK build.
    public static bool show_launcher = false;

    // strftime pattern the clock renders with. The default writes the weekday
    // with letters (e.g. "Sat 13 Jun  14:30"). Kept in sync with the
    // lumen-settings panel page default.
    public const string DEFAULT_CLOCK_FORMAT = "%a %d %b  %H:%M";
    public static string clock_format = DEFAULT_CLOCK_FORMAT;

    // Raw auto-hide behavior, resolved into a PanelWindow.Mode there (the enum
    // lives with the window). behavior_mode is the explicit "normal|hidden|push"
    // string; behavior_auto_hide is the legacy bool fallback when it's absent.
    public static string? behavior_mode = null;
    public static bool behavior_auto_hide = false;

    // Tray applet layout, from the "tray.order"/"tray.disabled" JSON arrays
    // (written by lumen-settings). tray_order is the full ordered list of applet
    // ids; tray_disabled is the subset toggled off. Absent tray.order leaves
    // tray_order at the catalog default and tray_disabled empty — byte-for-byte
    // identical to the old hardcoded tray. tray_enabled_order() resolves the two
    // against the shared catalog into what make_tray() actually builds.
    public static string[] tray_order = {};
    public static string[] tray_disabled = {};

    public static void load () {
        var vals = parse(LumenCommon.Paths.panel_json());

        at_top            = vals.get_string_member_with_default("position", "") == "top";
        open_indicator    = parse_indicator(vals.get_string_member_with_default("app.open-indicator", ""));
        active_indicator  = parse_active_indicator(vals.get_string_member_with_default("app.active-indicator", ""));
        multi_monitor     = vals.get_boolean_member_with_default("behavior.multi-monitor", false);
        per_monitor_apps  = vals.get_boolean_member_with_default("behavior.per-monitor-apps", false);
        tray_all_monitors = vals.get_boolean_member_with_default("behavior.tray-all-monitors", false);
        show_launcher     = vals.get_boolean_member_with_default("app.launcher-button", false);
        var fmt = vals.get_string_member_with_default("clock.format", "");
        if (fmt.strip() != "") clock_format = fmt;

        // Absent (null) and present-but-unrecognised mean different things here:
        // only an absent key falls back to the legacy auto-hide bool.
        behavior_mode      = vals.has_member("behavior.mode")
            ? vals.get_string_member_with_default("behavior.mode", "") : null;
        behavior_auto_hide = vals.get_boolean_member_with_default("behavior.auto-hide", false);

        tray_order    = get_string_array(vals, "tray.order");
        tray_disabled = get_string_array(vals, "tray.disabled");
        // No tray.order ⇒ fall back to the catalog's canonical order.
        if (tray_order.length == 0) {
            string[] defaults = {};
            foreach (var info in LumenTray.CATALOG) defaults += info.id;
            tray_order = defaults;
        }
    }

    // panel.json is a flat dotted-key object. Fail-soft: a missing or
    // unparseable file yields an empty object, so every member read falls back
    // to its default.
    static Json.Object parse (string path) {
        if (!FileUtils.test(path, FileTest.EXISTS)) return new Json.Object();
        var parser = new Json.Parser();
        try {
            parser.load_from_file(path);
        } catch (Error e) {
            stderr.printf("PanelConfig: load %s failed: %s\n", path, e.message);
            return new Json.Object();
        }
        var root = parser.get_root();
        if (root == null || root.get_node_type() != Json.NodeType.OBJECT) return new Json.Object();
        return root.get_object();
    }

    // String-array getter: strips, drops empties. Non-array/missing ⇒ empty.
    static string[] get_string_array (Json.Object o, string key) {
        string[] result = {};
        if (!o.has_member(key)) return result;
        var n = o.get_member(key);
        if (n.get_node_type() != Json.NodeType.ARRAY) return result;
        foreach (var elem in n.get_array().get_elements()) {
            if (elem.get_node_type() != Json.NodeType.VALUE) continue;
            if (elem.get_value_type() != typeof(string)) continue;
            var s = elem.get_string().strip();
            if (s != "") result += s;
        }
        return result;
    }

    // The resolved, enabled, ordered ids make_tray() iterates: start from
    // tray_order, append any catalog ids not already present (so a new built-in
    // applet appears after an upgrade without rewriting the config), drop the
    // disabled subset, and drop any id not in the catalog (stale/unknown).
    public static string[] tray_enabled_order () {
        var order = new Gee.ArrayList<string>();
        foreach (var id in tray_order) order.add(id);
        foreach (var info in LumenTray.CATALOG) {
            if (!order.contains(info.id)) order.add(info.id);
        }

        string[] result = {};
        foreach (var id in order) {
            if (id in tray_disabled) continue;
            if (!catalog_has(id)) continue;
            result += id;
        }
        return result;
    }

    static bool catalog_has (string id) {
        foreach (var info in LumenTray.CATALOG) {
            if (info.id == id) return true;
        }
        return false;
    }

    static OpenIndicator parse_indicator (string? s) {
        switch (s) {
            case "dot":     return OpenIndicator.DOT;
            case "corners": return OpenIndicator.CORNERS;
            case "glass":   return OpenIndicator.GLASS;
            case "round":   return OpenIndicator.ROUND;
            case "none":    return OpenIndicator.NONE;
            default:        return OpenIndicator.SHADE;
        }
    }

    static ActiveIndicator parse_active_indicator (string? s) {
        switch (s) {
            case "ring":      return ActiveIndicator.RING;
            case "sunshine":  return ActiveIndicator.SUNSHINE;
            case "glass":     return ActiveIndicator.GLASS;
            case "circle":    return ActiveIndicator.CIRCLE;
            case "underline": return ActiveIndicator.UNDERLINE;
            default:          return ActiveIndicator.UNDERLINE;
        }
    }
}
