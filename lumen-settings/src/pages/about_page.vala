using Gtk;

namespace LumenSettings {

    public class AboutPage : GLib.Object, SettingsPage {
        public string id        { owned get { return "about"; } }
        public string title     { owned get { return "About"; } }
        public string icon_name { owned get { return "help-about-symbolic"; } }

        public Gtk.Widget build() {
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 18) {
                margin_top = 24, margin_bottom = 24,
                margin_start = 24, margin_end = 24,
                halign = Gtk.Align.CENTER,
            };

            var title_label = new Gtk.Label("Lumen Settings") { xalign = 0.5f };
            title_label.add_css_class("lumen-about-title");
            box.append(title_label);

            var subtitle = new Gtk.Label("LumenShell session — settings front-end") {
                xalign = 0.5f,
            };
            subtitle.add_css_class("lumen-about-subtitle");
            box.append(subtitle);

            var build = new Gtk.Label("GTK4 / Vala") {
                xalign = 0.5f,
                margin_top = 12,
            };
            build.add_css_class("lumen-about-value");
            box.append(build);

            return box;
        }
    }
}
