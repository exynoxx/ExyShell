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
            return e.factory(spec);
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
