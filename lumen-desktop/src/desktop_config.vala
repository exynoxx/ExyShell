// ~/.config/lumen-shell/desktop.json — the desktop widget layout.
//
// Unlike panel.json (flat dotted keys) this is a real nested document,
// because widgets are a list and each carries its own free-form settings
// object:
//
//   {
//     "widgets": [
//       {
//         "type": "file-browser",
//         "shape": "rounded-rect",
//         "radius": 22,
//         "width": 900,
//         "height": 520,
//         "settings": { "root": "~", "show-hidden": false }
//       }
//     ]
//   }
//
// A missing or unreadable file yields one file-browser at defaults, so a
// fresh install shows something rather than an empty screen.

namespace LumenDesktop {

    // One widget instance as described by the config file. Geometry is in
    // logical pixels; v1 always centres, so x/y are unused but parsed, ready
    // for free placement.
    public class WidgetSpec : GLib.Object {
        public string type_name  { get; set; default = "file-browser"; }
        public string shape_name { get; set; default = "rounded-rect"; }
        public double radius     { get; set; default = 22.0; }
        public int width         { get; set; default = 900; }
        public int height        { get; set; default = 520; }
        public int x             { get; set; default = -1; }   // -1 = centre
        public int y             { get; set; default = -1; }
        public WidgetSettings settings { get; set; default = new WidgetSettings(); }

        public WidgetShape make_shape() {
            return WidgetShape.from_spec(shape_name, radius);
        }
    }

    public class DesktopConfig : GLib.Object {

        public static WidgetSpec[] widgets = {};

        public static string config_path() {
            return GLib.Path.build_filename(
                GLib.Environment.get_user_config_dir(), "lumen-shell", "desktop.json");
        }

        public static void load() {
            var path = config_path();
            if (!GLib.FileUtils.test(path, GLib.FileTest.EXISTS)) {
                widgets = { new WidgetSpec() };
                return;
            }

            try {
                var parser = new Json.Parser();
                parser.load_from_file(path);
                widgets = parse_root(parser.get_root());
            } catch (GLib.Error e) {
                warning("lumen-desktop: reading %s: %s", path, e.message);
                widgets = { new WidgetSpec() };
                return;
            }

            if (widgets.length == 0) {
                warning("lumen-desktop: %s has no widgets, using the default", path);
                widgets = { new WidgetSpec() };
            }
        }

        private static WidgetSpec[] parse_root(Json.Node? root) {
            WidgetSpec[] result = {};
            if (root == null || root.get_node_type() != Json.NodeType.OBJECT) return result;

            var obj = root.get_object();
            if (!obj.has_member("widgets")) return result;

            var member = obj.get_member("widgets");
            if (member.get_node_type() != Json.NodeType.ARRAY) return result;

            var arr = member.get_array();
            for (uint i = 0; i < arr.get_length(); i++) {
                var node = arr.get_element(i);
                if (node.get_node_type() != Json.NodeType.OBJECT) continue;
                result += parse_widget(node.get_object());
            }
            return result;
        }

        private static WidgetSpec parse_widget(Json.Object o) {
            var spec = new WidgetSpec();
            if (o.has_member("type"))   spec.type_name  = o.get_string_member("type");
            if (o.has_member("shape"))  spec.shape_name = o.get_string_member("shape");
            if (o.has_member("radius")) spec.radius     = o.get_double_member("radius");
            if (o.has_member("width"))  spec.width      = (int) o.get_int_member("width");
            if (o.has_member("height")) spec.height     = (int) o.get_int_member("height");
            if (o.has_member("x"))      spec.x          = (int) o.get_int_member("x");
            if (o.has_member("y"))      spec.y          = (int) o.get_int_member("y");

            if (o.has_member("settings")) {
                var sn = o.get_member("settings");
                if (sn.get_node_type() == Json.NodeType.OBJECT) {
                    var so = sn.get_object();
                    foreach (var key in so.get_members()) {
                        var v = scalar_to_string(so.get_member(key));
                        if (v != null) spec.settings.put(key, v);
                    }
                }
            }
            return spec;
        }

        // Settings are stored as strings and coerced on read (see
        // WidgetSettings), so accept whichever JSON scalar the user wrote.
        private static string? scalar_to_string(Json.Node node) {
            if (node.get_node_type() != Json.NodeType.VALUE) return null;
            var t = node.get_value_type();
            if (t == typeof(string)) return node.get_string();
            if (t == typeof(bool))   return node.get_boolean().to_string();
            if (t == typeof(int64))  return node.get_int().to_string();
            if (t == typeof(double)) {
                // Machine-facing: force '.' regardless of LC_NUMERIC.
                char[] buf = new char[double.DTOSTR_BUF_SIZE];
                return node.get_double().format(buf);
            }
            return null;
        }
    }
}
