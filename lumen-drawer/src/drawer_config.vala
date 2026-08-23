// Grid geometry, loaded once at startup (main.vala) from the
// ~/.config/lumen-shell/drawer.ini file that lumen-settings' Drawer page
// writes ([drawer] section: grid.cols, grid.rows, grid.margin). A missing file
// or key leaves the corresponding default in place, so an unconfigured session
// keeps the historical layout.
namespace LumenDrawer {

    public class DrawerConfig {
        public static int cols     = 6;
        public static int rows     = 4;
        public static int per_page = 24;

        // Edge insets shared between the grid pages and SearchResults so the
        // two views land tiles on the same cells when toggling between them.
        public static int margin_x = 200;
        public static int margin_y = 130;

        public static void load() {
            var kf = new KeyFile();
            try {
                kf.load_from_file(LumenCommon.Paths.drawer_ini(), KeyFileFlags.NONE);
            } catch (Error e) {
                return;   // no file yet, or unreadable: the defaults stand
            }

            int v = read_int(kf, "grid.cols");
            if (v > 0) cols = v;
            v = read_int(kf, "grid.rows");
            if (v > 0) rows = v;
            per_page = cols * rows;

            // A single configured value applies to all edges; left unset, the
            // asymmetric historical insets (200/130) are preserved.
            v = read_int(kf, "grid.margin");
            if (v >= 0) { margin_x = v; margin_y = v; }
        }

        // -1 for "absent or not an integer", which every caller treats as
        // "keep the default".
        private static int read_int(KeyFile kf, string key) {
            try {
                return kf.get_integer("drawer", key);
            } catch (Error e) {
                return -1;
            }
        }
    }
}
