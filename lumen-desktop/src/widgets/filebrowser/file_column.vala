// One directory's worth of rows — a single Miller column.
//
// Owns its own scroll area; the browser strip scrolls horizontally between
// columns, each column scrolls vertically within itself.

namespace LumenDesktop {

    public class FileColumn : Gtk.Widget {

        public const int WIDTH = 220;

        public GLib.File dir { get; construct; }
        public bool show_hidden { get; construct; }

        // Emitted when the user moves the selection (click or arrow key).
        // `entry` is null when the column is cleared.
        public signal void selection_changed(FsEntry? entry);
        // Emitted on Enter / double-click, i.e. "act on this".
        public signal void activated(FsEntry entry);

        private Gtk.ScrolledWindow scroller;
        private Gtk.Box rows_box;
        private GLib.List<FileRow> rows = new GLib.List<FileRow>();
        private FileRow? selected_row = null;
        private Gtk.Label? placeholder = null;

        public FileColumn(GLib.File dir, bool show_hidden) {
            Object(dir: dir, show_hidden: show_hidden);

            set_layout_manager(new Gtk.BinLayout());

            rows_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0) {
                margin_top = 6, margin_bottom = 6,
            };
            scroller = new Gtk.ScrolledWindow() {
                hscrollbar_policy = Gtk.PolicyType.NEVER,
                vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
                child = rows_box,
                hexpand = false,
                vexpand = true,
            };
            scroller.set_size_request(WIDTH, -1);
            scroller.set_parent(this);

            load.begin();
        }

        public override void dispose() {
            if (scroller != null) { scroller.unparent(); scroller = null; }
            base.dispose();
        }

        public override void measure(Gtk.Orientation orientation, int for_size,
                                     out int minimum, out int natural,
                                     out int minimum_baseline, out int natural_baseline) {
            minimum_baseline = -1;
            natural_baseline = -1;
            if (orientation == Gtk.Orientation.HORIZONTAL) {
                minimum = WIDTH;
                natural = WIDTH;
            } else {
                minimum = 0;
                natural = 0;
            }
        }

        private async void load() {
            GLib.List<FsEntry> entries;
            try {
                entries = yield FsModel.list_async(dir, show_hidden);
            } catch (GLib.Error e) {
                show_placeholder(e.message);
                return;
            }

            if (entries.length() == 0) {
                show_placeholder("Empty folder");
                return;
            }

            foreach (var entry in entries) {
                var row = new FileRow(entry);
                wire_row(row);
                rows_box.append(row);
                rows.append(row);
            }
        }

        // Errors and empty folders read the same way: a dim inline line, never
        // a dialog and never a crash.
        private void show_placeholder(string text) {
            placeholder = new Gtk.Label(text) {
                wrap = true,
                justify = Gtk.Justification.CENTER,
                margin_start = 10, margin_end = 10, margin_top = 10,
                xalign = 0.5f,
            };
            placeholder.add_css_class("fb-empty");
            rows_box.append(placeholder);
        }

        private void wire_row(FileRow row) {
            var click = new Gtk.GestureClick();
            click.pressed.connect((n_press, x, y) => {
                select_row(row, true);
                // Directories open a column on the first click (Finder-style);
                // files need a double-click to launch.
                if (n_press >= 2 && !row.entry.is_dir) activated(row.entry);
            });
            row.add_controller(click);
        }

        private void select_row(FileRow? row, bool notify_change) {
            if (selected_row == row) {
                if (notify_change && row != null) selection_changed(row.entry);
                return;
            }
            if (selected_row != null) selected_row.selected = false;
            selected_row = row;
            if (selected_row != null) {
                selected_row.selected = true;
                scroll_into_view(selected_row);
            }
            if (notify_change) selection_changed(row == null ? null : row.entry);
        }

        private void scroll_into_view(FileRow row) {
            var adj = scroller.get_vadjustment();
            if (adj == null) return;
            // Allocation is only meaningful once laid out; defer a tick.
            GLib.Idle.add(() => {
                Gtk.Allocation alloc;
                row.get_allocation(out alloc);
                double y = alloc.y;
                double h = alloc.height;
                if (y < adj.value) adj.value = y;
                else if (y + h > adj.value + adj.page_size) adj.value = y + h - adj.page_size;
                return GLib.Source.REMOVE;
            });
        }

        // --- keyboard navigation, driven by ColumnBrowser ---

        public bool move_selection(int delta) {
            uint n = rows.length();
            if (n == 0) return false;
            int idx = selected_row == null ? -1 : (int) rows.index(selected_row);
            int next = idx < 0 ? (delta > 0 ? 0 : (int) n - 1) : idx + delta;
            next = int.max(0, int.min(next, (int) n - 1));
            if (next == idx) return true;
            select_row(rows.nth_data(next), true);
            return true;
        }

        public void select_first_if_empty() {
            if (selected_row == null) move_selection(1);
        }

        public FsEntry? selected_entry() {
            return selected_row == null ? null : selected_row.entry;
        }

        public void activate_selected() {
            if (selected_row != null) activated(selected_row.entry);
        }

        public void clear_selection() {
            select_row(null, false);
        }
    }
}
