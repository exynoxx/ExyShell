// type-name -> widget factory.
//
// The only place that knows which widget types exist. A new widget type is
// one register() call in register_builtins() plus its own source file; the
// config parser, the host and the window stay untouched.

namespace LumenDesktop {

    public delegate DesktopWidget WidgetFactory(WidgetSpec spec);

    public class WidgetRegistry : GLib.Object {

        // Vala can't put a delegate straight into a HashTable, so wrap it.
        private class Entry {
            public WidgetFactory factory;
            public Entry(owned WidgetFactory f) { this.factory = (owned) f; }
        }

        private static GLib.HashTable<string, Entry>? types = null;

        public static void register(string type_name, owned WidgetFactory factory) {
            ensure();
            types.insert(type_name, new Entry((owned) factory));
        }

        // Returns null (with a warning) for an unknown type so one bad config
        // entry drops that widget rather than taking the desktop down.
        public static DesktopWidget? create(WidgetSpec spec) {
            ensure();
            var e = types.lookup(spec.type_name);
            if (e == null) {
                warning("lumen-desktop: unknown widget type '%s'", spec.type_name);
                return null;
            }
            var w = e.factory(spec);
            apply_chrome(w, spec);
            return w;
        }

        // Chrome every widget type gets for free, so a subclass only ever has
        // to supply content.
        private static void apply_chrome(DesktopWidget w, WidgetSpec spec) {
            w.border_width = (float) spec.border_width;

            var c = Gdk.RGBA();
            if (c.parse(spec.border_color)) {
                w.border_color = c;
            } else {
                warning("lumen-desktop: unparseable border-color '%s', using white",
                    spec.border_color);
            }
        }

        private static void ensure() {
            if (types == null) {
                types = new GLib.HashTable<string, Entry>(str_hash, str_equal);
            }
        }

        public static void register_builtins() {
            register("file-browser", (spec) => new FileBrowserWidget(spec));
        }
    }
}
