// Base class for everything that can live on the desktop.
//
// A DesktopWidget is chrome + one content child. The chrome (silhouette,
// background fill, inner edge shadow) is entirely delegated to a WidgetShape,
// so a subclass only ever supplies content. v1 has one subclass
// (FileBrowserWidget); clock / weather / app-chooser widgets slot in the same
// way and need to override nothing but set_content().
//
// The chrome also carries the widget's own edit affordances — a pin, plus a
// close glyph while unpinned — drawn inside the frame by ChromeButtons. An
// unpinned widget can be dragged **by its frame only**, so the content stays
// live and browsable the whole time. The widget itself never moves anything:
// it reports intent through move_started / move_delta / move_finished and
// leaves placement (and persistence) to WidgetHost.
//
// Pinned state is deliberately runtime-only. Position and existence persist
// to desktop.json; a restart always comes back pinned.

namespace LumenDesktop {

    public abstract class DesktopWidget : Gtk.Widget {

        public WidgetShape shape { get; construct set; }
        public WidgetSettings settings { get; construct set; }

        public Gdk.RGBA background { get; set; }
        public Gdk.RGBA shadow_color { get; set; }
        public float shadow_blur { get; set; default = 18.0f; }
        public float shadow_spread { get; set; default = 1.0f; }

        // The frame: the silhouette filled with border_color, the content
        // clipped to a smaller opening inside it. How much smaller is the
        // shape's call — see WidgetShape.frame_insets.
        public Gdk.RGBA border_color { get; set; }
        public float border_width { get; set; default = 5.0f; }

        // Unpinned means "being arranged": draggable by the frame, and showing
        // the close glyph. Never persisted.
        public bool pinned { get; private set; default = true; }

        // Move intent, in the widget's own coordinates. WidgetHost turns these
        // into a placement and writes the result back to desktop.json.
        public signal void move_started();
        public signal void move_delta(double dx, double dy);
        public signal void move_finished();

        // The user asked for this widget to be removed from the desktop
        // entirely. Travels up to DesktopApp, which owns the config file.
        public signal void close_requested();

        private Gtk.Widget? content = null;
        private ChromeHit hover = ChromeHit.NONE;
        private bool dragging = false;

        construct {
            // Content is clipped to the silhouette, so a child that overflows
            // (a scrolled column strip, say) never leaks past the corners.
            overflow = Gtk.Overflow.HIDDEN;
            background = { 0.10f, 0.11f, 0.13f, 0.88f };
            shadow_color = { 0.0f, 0.0f, 0.0f, 0.45f };
            border_color = { 1.0f, 1.0f, 1.0f, 1.0f };

            install_chrome_controllers();
        }

        // Where the pin / close glyphs live. Empty until the shape and a size
        // exist, which is why every caller re-asks rather than caching.
        private Cairo.RectangleInt chrome_band() {
            int w = get_width();
            int h = get_height();
            if (w <= 0 || h <= 0) {
                return Cairo.RectangleInt() { x = 0, y = 0, width = 0, height = 0 };
            }
            return shape.chrome_rect(w, h, float.max(0, border_width));
        }

        private ChromeHit chrome_hit(double x, double y) {
            return ChromeButtons.hit_test(chrome_band(), !pinned, x, y);
        }

        // True inside the content opening — where the frame is not, and so
        // where a drag must not start.
        private bool in_content(double x, double y) {
            var f = frame();
            return x >= f[3] && x < get_width() - f[1]
                && y >= f[0] && y < get_height() - f[2];
        }

        private void install_chrome_controllers() {
            var click = new Gtk.GestureClick();
            click.set_button(Gdk.BUTTON_PRIMARY);
            click.released.connect((n, x, y) => {
                switch (chrome_hit(x, y)) {
                    case ChromeHit.PIN:
                        pinned = !pinned;
                        hover = chrome_hit(x, y);
                        queue_draw();
                        click.set_state(Gtk.EventSequenceState.CLAIMED);
                        break;
                    case ChromeHit.CLOSE:
                        click.set_state(Gtk.EventSequenceState.CLAIMED);
                        close_requested();
                        break;
                    default:
                        break;
                }
            });
            add_controller(click);

            var drag = new Gtk.GestureDrag();
            drag.set_button(Gdk.BUTTON_PRIMARY);
            drag.drag_begin.connect((sx, sy) => {
                if (pinned || in_content(sx, sy) || chrome_hit(sx, sy) != ChromeHit.NONE) {
                    drag.set_state(Gtk.EventSequenceState.DENIED);
                    return;
                }
                dragging = true;
                move_started();
            });
            drag.drag_update.connect((ox, oy) => {
                if (dragging) move_delta(ox, oy);
            });
            drag.drag_end.connect((ox, oy) => {
                if (!dragging) return;
                dragging = false;
                move_finished();
            });
            add_controller(drag);

            var motion = new Gtk.EventControllerMotion();
            motion.motion.connect(update_pointer_feedback);
            motion.leave.connect(() => {
                if (hover == ChromeHit.NONE) return;
                hover = ChromeHit.NONE;
                set_cursor(null);
                queue_draw();
            });
            add_controller(motion);

            notify["pinned"].connect(queue_draw);
        }

        private void update_pointer_feedback(double x, double y) {
            var hit = chrome_hit(x, y);
            if (hit != hover) {
                hover = hit;
                queue_draw();
            }

            if (hit != ChromeHit.NONE) {
                set_cursor_from_name("pointer");
            } else if (!pinned && !in_content(x, y)) {
                set_cursor_from_name(dragging ? "grabbing" : "grab");
            } else {
                set_cursor(null);
            }
        }

        // Frame widths in whole pixels, so the content inset and the drawn
        // opening can never disagree by a sub-pixel and leave a seam.
        private float[] frame() {
            var f = shape.frame_insets(float.max(0, border_width));
            return { GLib.Math.ceilf(f[0]), GLib.Math.ceilf(f[1]),
                     GLib.Math.ceilf(f[2]), GLib.Math.ceilf(f[3]) };
        }

        // Subclasses call this exactly once, from their constructor.
        protected void set_content(Gtk.Widget child) {
            if (content != null) content.unparent();
            content = child;
            content.set_parent(this);
        }

        public override void dispose() {
            if (content != null) {
                content.unparent();
                content = null;
            }
            base.dispose();
        }

        public override Gtk.SizeRequestMode get_request_mode() {
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
        }

        public override void measure(Gtk.Orientation orientation, int for_size,
                                     out int minimum, out int natural,
                                     out int minimum_baseline, out int natural_baseline) {
            minimum = 0;
            natural = 0;
            minimum_baseline = -1;
            natural_baseline = -1;
            if (content == null) return;

            var f = frame();
            int chrome = (int) (orientation == Gtk.Orientation.HORIZONTAL
                                ? f[1] + f[3] : f[0] + f[2]);

            int cmin, cnat, cminb, cnatb;
            content.measure(orientation, int.max(-1, for_size - chrome),
                            out cmin, out cnat, out cminb, out cnatb);
            minimum = cmin + chrome;
            natural = cnat + chrome;
        }

        public override void size_allocate(int width, int height, int baseline) {
            if (content == null) return;
            var f = frame();
            content.allocate(int.max(0, width - (int) (f[1] + f[3])),
                             int.max(0, height - (int) (f[0] + f[2])),
                             baseline,
                             new Gsk.Transform().translate({ f[3], f[0] }));
        }

        public override void snapshot(Gtk.Snapshot s) {
            int w = get_width();
            int h = get_height();
            if (w <= 0 || h <= 0) return;

            var f = frame();

            shape.push_clip(s, w, h);
            shape.fill(s, w, h, border_color);

            shape.push_content_clip(s, w, h, f);
            shape.fill(s, w, h, background);
            if (content != null) snapshot_child(content, s);
            shape.inner_shadow(s, w, h, f, shadow_color, shadow_blur, shadow_spread);
            s.pop();

            // Inside the silhouette clip but outside the content opening, so
            // the glyphs sit in the frame and can never spill past the edge.
            ChromeButtons.snapshot(s, shape.chrome_rect(w, h, float.max(0, border_width)),
                                   pinned, hover, background);

            s.pop();
        }
    }
}
