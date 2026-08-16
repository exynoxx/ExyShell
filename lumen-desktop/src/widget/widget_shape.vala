// Widget silhouettes.
//
// A WidgetShape owns everything about *what a widget looks like around its
// edges*: the clip its content is confined to, the background fill, and the
// inner shadow that gives the panel its recessed feel. DesktopWidget never
// hard-codes a rounded rectangle — it just asks the shape to draw. Adding a
// circle, a squircle or a hexagon later means one new subclass here and one
// new string case in from_spec(); nothing else in the tree changes.

namespace LumenDesktop {

    public abstract class WidgetShape : GLib.Object {

        // Confine everything drawn until the matching pop() to the silhouette.
        // Implementations must push exactly one clip node.
        public abstract void push_clip(Gtk.Snapshot s, int w, int h);

        // Fill the silhouette. Called immediately after push_clip, so a plain
        // rect fill is enough for any convex shape — the clip does the work.
        public virtual void fill(Gtk.Snapshot s, int w, int h, Gdk.RGBA color) {
            var r = Graphene.Rect();
            r.init(0, 0, w, h);
            s.append_color(color, r);
        }

        // The recessed edge falloff, drawn on top of the content but still
        // inside the clip. Shapes that have no notion of an inset shadow may
        // leave this empty.
        public abstract void inner_shadow(Gtk.Snapshot s, int w, int h,
                                          Gdk.RGBA color, float blur, float spread);

        // Build a shape from a widget spec's "shape" string plus its numeric
        // parameters. Unknown names fall back to a rounded rectangle rather
        // than failing to place the widget at all.
        public static WidgetShape from_spec(string name, double radius) {
            switch (name) {
                case "rounded-rect":
                case "rounded-rectangle":
                case "":
                    return new RoundedRectShape((float) radius);
                case "rect":
                case "square":
                    return new RoundedRectShape(0);
                case "pill":
                    // Radius resolved at draw time from the height.
                    return new RoundedRectShape(-1);
                default:
                    warning("lumen-desktop: unknown widget shape '%s', using rounded-rect", name);
                    return new RoundedRectShape((float) radius);
            }
        }
    }

    // The v1 shape: a rectangle with uniform corner radius. A negative radius
    // means "pill" — half the height, resolved per draw (same convention as
    // lumen-osd's Pill).
    public class RoundedRectShape : WidgetShape {

        private float radius;

        public RoundedRectShape(float radius) {
            this.radius = radius;
        }

        private float effective_radius(int w, int h) {
            if (radius < 0) return h / 2.0f;
            // Never let the radius exceed half the smaller side, or GSK draws
            // a distorted silhouette.
            return float.min(radius, float.min(w, h) / 2.0f);
        }

        private Gsk.RoundedRect rounded(int w, int h, float inset) {
            var r = Graphene.Rect();
            r.init(inset, inset, w - 2 * inset, h - 2 * inset);
            var rr = Gsk.RoundedRect();
            rr.init_from_rect(r, float.max(0, effective_radius(w, h) - inset));
            return rr;
        }

        public override void push_clip(Gtk.Snapshot s, int w, int h) {
            var rr = rounded(w, h, 0);
            s.push_rounded_clip(rr);
        }

        public override void inner_shadow(Gtk.Snapshot s, int w, int h,
                                          Gdk.RGBA color, float blur, float spread) {
            if (color.alpha <= 0 || (blur <= 0 && spread <= 0)) return;
            var rr = rounded(w, h, 0);
            // append_inset_shadow draws the shadow ring directly, on top of
            // whatever content has already been snapshotted inside the clip.
            s.append_inset_shadow(rr, color, 0, 0, spread, blur);
        }
    }
}
