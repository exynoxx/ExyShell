// Places widgets on the desktop surface.
//
// Each widget keeps a position of its own, resolved per monitor: the host is
// built with the connector name of the output it lives on, and asks the spec
// what that monitor's coordinates are. A widget with no entry for this monitor
// falls back to the spec's top-level x/y, and -1 still means "centre" — so a
// fresh config with no positions at all behaves exactly as it did before
// anything was draggable.
//
// Dragging goes: DesktopWidget reports move intent -> the host resolves it
// into pixels and re-allocates -> on drop the clamped result is written back
// to desktop.json. The widget never knows where it is, and the config layer
// never knows about pointers.

namespace LumenDesktop {

    public class WidgetHost : Gtk.Widget {

        // One placed widget: what it is, where it is, and where a drag in
        // progress started from.
        private class Placement {
            public DesktopWidget widget;
            public WidgetSpec spec;
            public int x;             // -1 = centre on this axis
            public int y;
            public int drag_x;        // resolved pixel origin at drag start
            public int drag_y;

            public Placement(DesktopWidget widget, WidgetSpec spec, int x, int y) {
                this.widget = widget;
                this.spec = spec;
                this.x = x;
                this.y = y;
            }
        }

        private GLib.GenericArray<Placement> placements
            = new GLib.GenericArray<Placement>();

        // Connector name of the output this host is on ("eDP-1"), or
        // "default" when there is no monitor to name.
        private string monitor_key;

        // Emitted whenever the set or geometry of placed widgets changes, so
        // the window can re-clip its Wayland input region.
        public signal void layout_changed();

        // A widget's close glyph was pressed. The config file is owned further
        // up (DesktopApp), because a removal has to take effect on every
        // monitor, not just this one.
        public signal void widget_removed(WidgetSpec spec);

        public WidgetHost(WidgetSpec[] specs, string monitor_key) {
            this.monitor_key = monitor_key;

            foreach (var spec in specs) {
                var w = WidgetRegistry.create(spec);
                if (w == null) continue;

                int px, py;
                spec.resolve_position(monitor_key, out px, out py);

                var p = new Placement(w, spec, px, py);
                placements.add(p);

                w.set_parent(this);
                wire(p);
            }
        }

        private void wire(Placement p) {
            p.widget.move_started.connect(() => {
                // Resolve whatever the widget currently is — centred or not —
                // into absolute pixels, so the drag has a fixed origin.
                var r = place(p, get_width(), get_height());
                p.drag_x = r.x;
                p.drag_y = r.y;
            });

            p.widget.move_delta.connect((dx, dy) => {
                p.x = p.drag_x + (int) dx;
                p.y = p.drag_y + (int) dy;
                queue_allocate();
            });

            p.widget.move_finished.connect(() => {
                // place() clamps to the output; persist what was actually
                // used, or a widget dragged off the edge would come back at
                // coordinates it can never be drawn at.
                var r = place(p, get_width(), get_height());
                p.x = r.x;
                p.y = r.y;
                DesktopConfig.save_position(p.spec, monitor_key, r.x, r.y);
            });

            p.widget.close_requested.connect(() => widget_removed(p.spec));
        }

        public override void dispose() {
            for (int i = 0; i < placements.length; i++) {
                placements.get(i).widget.unparent();
            }
            placements = new GLib.GenericArray<Placement>();
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
            for (int i = 0; i < placements.length; i++) {
                var p = placements.get(i);
                var r = place(p, width, height);
                p.widget.allocate(r.width, r.height, -1,
                    new Gsk.Transform().translate({ (float) r.x, (float) r.y }));
            }
            layout_changed();
        }

        // Where one widget goes: its configured size at its own coordinates,
        // centred on any axis it has none for. Clamped so a widget dragged past
        // an edge — or an oversized one — still lands fully on screen.
        private Cairo.RectangleInt place(Placement p, int host_w, int host_h) {
            int cw = int.min(p.spec.width, host_w);
            int ch = int.min(p.spec.height, host_h);
            int cx = p.x >= 0 ? p.x : (host_w - cw) / 2;
            int cy = p.y >= 0 ? p.y : (host_h - ch) / 2;
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

            for (int i = 0; i < placements.length; i++) {
                var p = placements.get(i);
                var box = place(p, host_w, host_h);
                foreach (var hit in p.widget.shape.hit_rects(box.width, box.height)) {
                    hit.x += box.x;
                    hit.y += box.y;
                    rects += hit;
                }
            }
            return rects;
        }

        public bool is_empty() { return placements.length == 0; }
    }
}
