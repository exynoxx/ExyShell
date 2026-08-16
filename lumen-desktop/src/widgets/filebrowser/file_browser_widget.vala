// The v1 desktop widget: a Miller-column file browser.
//
// Per-instance settings (the "settings" object of its desktop.json entry):
//   root          path the leftmost column starts at   (default "~")
//   show-hidden   include dotfiles and backups         (default false)

namespace LumenDesktop {

    public class FileBrowserWidget : DesktopWidget {

        public FileBrowserWidget(WidgetSpec spec) {
            Object(shape: spec.make_shape(), settings: spec.settings);

            var root_path = settings.get_path("root", GLib.Environment.get_home_dir());
            var root = GLib.File.new_for_path(root_path);

            // A configured root that has gone away would leave the widget
            // permanently blank; fall back rather than show nothing.
            if (root.query_file_type(GLib.FileQueryInfoFlags.NONE, null)
                    != GLib.FileType.DIRECTORY) {
                warning("lumen-desktop: file-browser root '%s' is not a directory, using $HOME",
                    root_path);
                root = GLib.File.new_for_path(GLib.Environment.get_home_dir());
            }

            set_content(new ColumnBrowser(root, settings.get_bool("show-hidden", false)));
        }
    }
}
