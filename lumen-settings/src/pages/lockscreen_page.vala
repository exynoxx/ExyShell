using LumenCommon;
using Gtk;

namespace LumenSettings {

    // Lockscreen settings — writes ~/.config/lumen-shell/lockscreen.json, which
    // lumen-lockscreen reads via its Theme loader. Restarting lumen-lockscreen
    // re-reads the file.
    public class LockscreenPage : GLib.Object, SettingsPage {
        public string id        { owned get { return "lockscreen"; } }
        public string title     { owned get { return "Lock Screen"; } }
        public string icon_name { owned get { return "system-lock-screen-symbolic"; } }

        JsonRows rows;

        public Gtk.Widget build() {
            rows = new JsonRows(new JsonStore(Paths.lockscreen_json()));

            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 18) {
                margin_top = 18, margin_bottom = 18,
                margin_start = 18, margin_end = 18,
            };

            var behavior = new BoxedList("Behaviour");
            // Stored in ms, shown in seconds.
            behavior.add_row(rows.int_row("lockscreen.idle-timeout-ms", "Auto-lock when idle",
                0, 3600, 30, 300000, "seconds of inactivity before locking (0 = never)", 1000));
            behavior.add_row(rows.bool_row("lockscreen.show-power-menu", "Show power menu", true,
                "suspend / restart / shut down buttons on the lock screen"));
            box.append(behavior);

            var look = new BoxedList("Appearance");
            look.add_row(rows.int_row("lockscreen.blur-radius", "Backdrop blur",
                0, 64, 1, 12, "px of blur over the wallpaper backdrop"));
            look.add_row(rows.color_row("lockscreen.scrim", "Scrim tint",
                "#00000059", "colour tinting the blurred backdrop"));
            box.append(look);

            return box;
        }

        public override string? restart_target() { return "lumen-lockscreen"; }
    }
}
