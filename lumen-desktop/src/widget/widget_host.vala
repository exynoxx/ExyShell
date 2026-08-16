// Places widgets on the desktop surface.
//
// v1 is deliberately minimal: every widget is laid out at its configured size
// and centred, so a single fixed widget is all you get. The seam for the
// eventual "user creates, moves and pins widgets" work is entirely inside
// place() — free coordinates already round-trip through WidgetSpec.x/y, and
// widget_rects() already reports whatever geometry was used, so the window's
// input region follows automatically.

namespace LumenDesktop {

    public class WidgetHost : Gtk.Widget {

        private GLib.List<DesktopWidget> children = new GLib.List<DesktopWidget>();

        // Emitted whenever the set or geometry of placed widgets changes, so
        // the window can re-clip its Wayland input region.
        public signal void layout_changed();

        public WidgetHost(WidgetSpec[] specs) {
            foreach (var spec in specs) {
                var w = WidgetRegistry.create(spec);
                if (w == null) continue;
                w.set_data<WidgetSpec>("spec", spec);
                w.set_parent(this);
                children.append(w);
            }
        }

        public override void dispose() {
            foreach (var w in children) w.unparent();
            children = new GLib.List<DesktopWidget>();
            base.dispose();
        }

        public override Gtk.SizeRequestMode get_request_mode() {
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
        }

        // The host always fills the whole output; it never asks for space of
        // its own, or the layer surface would try to shrink to the widgets.
        public override void measure(Gtk.Orientation orientation, int for_size,
                                     out int minimum, out int natural,
                                     out int minimum_baseline, out int natural_baseline) {
            minimum = 0;
            natural = 0;
            minimum_baseline = -1;
            natural_baseline = -1;
        }

        public override void size_allocate(int width, int height, int baseline) {
            foreach (var w in children) {
                var r = place(w, width, height);
                w.allocate(r.width, r.height, -1,
                    new Gsk.Transform().translate({ (float) r.x, (float) r.y }));
            }
            layout_changed();
        }

        // Where one widget goes. v1: configured size, centred unless the spec
        // pins explicit coordinates. Clamped so an oversized widget still
        // lands fully on screen.
        private Cairo.RectangleInt place(DesktopWidget w, int host_w, int host_h) {
            var spec = w.get_data<WidgetSpec>("spec");
            int cw = int.min(spec.width, host_w);
            int ch = int.min(spec.height, host_h);
            int cx = spec.x >= 0 ? spec.x : (host_w - cw) / 2;
            int cy = spec.y >= 0 ? spec.y : (host_h - ch) / 2;
            cx = int.max(0, int.min(cx, host_w - cw));
            cy = int.max(0, int.min(cy, host_h - ch));
            return Cairo.RectangleInt() { x = cx, y = cy, width = cw, height = ch };
        }

        // The rectangles the window must make click-through-proof. Everything
        // outside them stays transparent to input so the wallpaper below keeps
        // receiving clicks (Win+D peek dismissal, etc.). A widget contributes
        // its shape's rects, not its bounding box, so the empty corner beside
        // a folder tab stays click-through too.
        public Cairo.RectangleInt[] widget_rects() {
            Cairo.RectangleInt[] rects = {};
            int host_w = get_width();
            int host_h = get_height();
            if (host_w <= 0 || host_h <= 0) return rects;
            foreach (var w in children) {
                var box = place(w, host_w, host_h);
                foreach (var hit in w.shape.hit_rects(box.width, box.height)) {
                    hit.x += box.x;
                    hit.y += box.y;
                    rects += hit;
                }
            }
            return rects;
        }

        public bool is_empty() { return children.length() == 0; }
    }
}
