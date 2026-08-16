// One row in a column: [icon] name [chevron for directories].
//
// Snapshot-drawn rather than composed from stock widgets, matching the house
// style for dense list rows (lumen-panel/src/components/wifi/wifirow.vala).

namespace LumenDesktop {

    public class FileRow : Gtk.Widget {

        public const int ROW_HEIGHT = 28;
        private const int ICON_SIZE = 16;
        private const int PAD_X     = 8;
        private const int GAP       = 8;
        private const int CHEVRON_W = 10;

        public FsEntry entry { get; construct; }

        private bool _selected = false;
        public bool selected {
            get { return _selected; }
            set { if (_selected != value) { _selected = value; queue_draw(); } }
        }

        private Gdk.Paintable? icon_paintable = null;

        public FileRow(FsEntry entry) {
            Object(entry: entry);
            hexpand = true;
            load_icon();
        }

        private void load_icon() {
            if (entry.icon == null) return;
            var display = Gdk.Display.get_default();
            if (display == null) return;
            var theme = Gtk.IconTheme.get_for_display(display);
            icon_paintable = theme.lookup_by_gicon(
                entry.icon, ICON_SIZE, scale_factor,
                Gtk.TextDirection.NONE, Gtk.IconLookupFlags.FORCE_SYMBOLIC);
        }

        public override Gtk.SizeRequestMode get_request_mode() {
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
        }

        public override void measure(Gtk.Orientation orientation, int for_size,
                                     out int minimum, out int natural,
                                     out int minimum_baseline, out int natural_baseline) {
            minimum_baseline = -1;
            natural_baseline = -1;
            if (orientation == Gtk.Orientation.VERTICAL) {
                minimum = ROW_HEIGHT;
                natural = ROW_HEIGHT;
                return;
            }
            var layout = create_pango_layout(entry.display_name);
            int tw, th;
            layout.get_pixel_size(out tw, out th);
            int want = PAD_X * 2 + ICON_SIZE + GAP + tw + GAP + CHEVRON_W;
            // The column, not the row, decides the final width; ask for a
            // modest minimum so a long file name doesn't blow the layout up.
            minimum = int.min(want, 120);
            natural = want;
        }

        public override void snapshot(Gtk.Snapshot s) {
            int w = get_width();
            int h = get_height();
            if (w <= 0 || h <= 0) return;

            if (_selected) {
                var r = Graphene.Rect();
                r.init(2, 1, w - 4, h - 2);
                var rr = Gsk.RoundedRect();
                rr.init_from_rect(r, 6);
                s.push_rounded_clip(rr);
                s.append_color({ 1.0f, 1.0f, 1.0f, 0.16f }, r);
                s.pop();
            }

            int x = PAD_X;

            if (icon_paintable != null) {
                s.save();
                var pt = Graphene.Point();
                pt.init(x, (h - ICON_SIZE) / 2);
                s.translate(pt);
                icon_paintable.snapshot(s, ICON_SIZE, ICON_SIZE);
                s.restore();
            }
            x += ICON_SIZE + GAP;

            int text_w = int.max(0, w - x - PAD_X - (entry.is_dir ? CHEVRON_W + GAP : 0));
            var layout = create_pango_layout(entry.display_name);
            layout.set_ellipsize(Pango.EllipsizeMode.MIDDLE);
            layout.set_width(text_w * Pango.SCALE);
            int tw, th;
            layout.get_pixel_size(out tw, out th);

            var fg = Gdk.RGBA() { red = 1.0f, green = 1.0f, blue = 1.0f, alpha = 0.92f };
            s.save();
            var tp = Graphene.Point();
            tp.init(x, (h - th) / 2);
            s.translate(tp);
            s.append_layout(layout, fg);
            s.restore();

            if (entry.is_dir) draw_chevron(s, w - PAD_X - CHEVRON_W, h);
        }

        // A small right-pointing "›" telling the user this row expands into
        // the next column.
        private void draw_chevron(Gtk.Snapshot s, int x, int h) {
            var color = Gdk.RGBA() { red = 1.0f, green = 1.0f, blue = 1.0f, alpha = 0.45f };
            var builder = new Gsk.PathBuilder();
            float cy = h / 2.0f;
            builder.move_to(x + 2.0f, cy - 4.0f);
            builder.line_to(x + 6.0f, cy);
            builder.line_to(x + 2.0f, cy + 4.0f);
            var stroke = new Gsk.Stroke(1.5f);
            stroke.set_line_cap(Gsk.LineCap.ROUND);
            stroke.set_line_join(Gsk.LineJoin.ROUND);
            s.append_stroke(builder.to_path(), stroke, color);
        }
    }
}
