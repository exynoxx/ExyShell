// lumen-desktop — the desktop widget layer.
//
// One always-mapped BOTTOM-layer surface per monitor, hosting persistent
// desktop widgets above the wallpaper and below every app window. v1 places a
// single centred widget (a Miller-column file browser); the widget framework
// under src/widget/ is what makes the rest additive.

namespace LumenDesktop {

    public class DesktopApp : Gtk.Application {

        private GLib.GenericArray<DesktopWindow> wins
            = new GLib.GenericArray<DesktopWindow>();
        private bool started = false;
        private bool removing = false;

        construct {
            application_id = "org.lumenshell.Desktop";
        }

        protected override void activate() {
            if (!started) {
                started = true;

                WidgetRegistry.register_builtins();
                DesktopConfig.load();

                build_windows();

                var monitors = Gdk.Display.get_default().get_monitors();
                monitors.items_changed.connect((p, r, a) => rebuild_windows());
            }
            for (int i = 0; i < wins.length; i++) wins.get(i).present();
        }

        // Every monitor gets its own copy of the configured widgets. Each
        // window builds its own widget instances (a Gtk.Widget can only have
        // one parent), so per-monitor state stays independent — browsing to a
        // different folder on one screen does not disturb the other.
        private void build_windows() {
            var monitors = Gdk.Display.get_default().get_monitors();
            uint n = monitors.get_n_items();
            if (n == 0) {
                add_window_for(null);
                return;
            }
            for (uint i = 0; i < n; i++) {
                var mon = monitors.get_item(i) as Gdk.Monitor;
                add_window_for(mon);
            }
        }

        private void add_window_for(Gdk.Monitor? monitor) {
            var win = new DesktopWindow(this, monitor, DesktopConfig.widgets);
            win.widget_removed.connect(remove_widget);
            wins.add(win);
        }

        // Removing a widget is a config edit, so it has to reach every
        // monitor's copy — hence a full reload and rebuild rather than
        // dropping one child. Deferred to an idle callback because we are
        // inside a signal emitted by the very window about to be destroyed.
        private void remove_widget(WidgetSpec spec) {
            if (removing) return;
            removing = true;

            DesktopConfig.remove_widget(spec);
            GLib.Idle.add(() => {
                DesktopConfig.load();
                rebuild_windows();
                removing = false;
                return GLib.Source.REMOVE;
            });
        }

        private void rebuild_windows() {
            for (int i = 0; i < wins.length; i++) wins.get(i).destroy();
            wins = new GLib.GenericArray<DesktopWindow>();
            build_windows();
            for (int i = 0; i < wins.length; i++) wins.get(i).present();
        }
    }
}

int main(string[] args) {
    var app = new LumenDesktop.DesktopApp();
    return app.run(args);
}
