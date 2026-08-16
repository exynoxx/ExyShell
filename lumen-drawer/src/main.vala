// The window is created once at activate() and stays mapped for the lifetime
// of the process — there is no hide/show lifecycle, so no hold() and no
// command-line flag handling.
public class DrawerApp : Gtk.Application {

    private GLib.GenericArray<DrawerWindow> wins = new GLib.GenericArray<DrawerWindow>();
    private bool bound = false;
    private bool hotplug_wired = false;
    private AppInfoMonitor app_monitor;   // keep a ref so it isn't collected
    private uint refresh_source = 0;

    construct {
        application_id = "dev.lumen.drawer";
    }

    protected override void activate() {
        if (!bound) {
            // Bind foreign-toplevel before any window is shown so its
            // focus_changed handler sees the initial state on map.
            DrawerToplevels.instance.bind();
            bound = true;

            // Load grid geometry from drawer.ini before any window is built;
            // lumen-settings' Drawer page writes cols/rows/margin there.
            LumenDrawer.DrawerConfig.load();
            GRID_COLS = LumenDrawer.DrawerConfig.cols;
            GRID_ROWS = LumenDrawer.DrawerConfig.rows;
            PER_PAGE  = GRID_COLS * GRID_ROWS;
            if (LumenDrawer.DrawerConfig.margin >= 0) {
                // A single configured value applies to all edges; left unset,
                // the asymmetric historical insets (200/130) are preserved.
                PAGE_MARGIN_X = LumenDrawer.DrawerConfig.margin;
                PAGE_MARGIN_Y = LumenDrawer.DrawerConfig.margin;
            }

            build_windows();

            // Start hidden behind a closed curtain. A no-op on a fresh session,
            // but if lumen-drawer restarted while peeked this hides the grid.
            LumenDrawer.CurtainIpc.close();

            if (!hotplug_wired) {
                var monitors = Gdk.Display.get_default().get_monitors();
                monitors.items_changed.connect((p, r, a) => rebuild_windows());
                hotplug_wired = true;

                // Auto-refresh the grid when apps are installed/removed (dnf,
                // flatpak, …). AppInfoMonitor watches every applications/ dir on
                // XDG_DATA_DIRS and invalidates GIO's AppInfo cache, so the
                // debounced reload() below sees the new set.
                app_monitor = AppInfoMonitor.get();
                app_monitor.changed.connect(schedule_app_refresh);
            }
        }
        for (int i = 0; i < wins.length; i++) wins.get(i).present();
    }

    // A package transaction fires `changed` many times; coalesce into one reload.
    private void schedule_app_refresh() {
        if (refresh_source != 0) GLib.Source.remove(refresh_source);
        refresh_source = GLib.Timeout.add(1500, () => {
            refresh_source = 0;
            for (int i = 0; i < wins.length; i++) wins.get(i).reload();
            return GLib.Source.REMOVE;
        });
    }

    // One drawer per monitor. The curtain/slide peek is per-output, so every
    // monitor needs its own grid surface for a peek on that output to reveal
    // anything (otherwise a peek on a monitor with no grid shows only the grey
    // backdrop). All drawers are independently focusable; the compositor routes
    // the keyboard to the grid on whichever output is active
    // (wayfire-curtain-peek on reveal, wayfire-default-focus thereafter).
    void build_windows() {
        var monitors = Gdk.Display.get_default().get_monitors();
        uint n = monitors.get_n_items();
        if (n == 0) {
            wins.add(new DrawerWindow(this, null));
            return;
        }
        for (uint i = 0; i < n; i++) {
            var mon = monitors.get_item(i) as Gdk.Monitor;
            wins.add(new DrawerWindow(this, mon));
        }
    }

    void rebuild_windows() {
        for (int i = 0; i < wins.length; i++) wins.get(i).destroy();
        wins = new GLib.GenericArray<DrawerWindow>();
        build_windows();
        for (int i = 0; i < wins.length; i++) wins.get(i).present();
    }
}

int main(string[] args) {
    var app = new DrawerApp();
    return app.run(args);
}
