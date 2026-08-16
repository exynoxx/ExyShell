// Widget silhouettes.
//
// A WidgetShape owns everything about *what a widget looks like around its
// edges*: the clip its content is confined to, the background fill, the frame
// widths the content must be inset by, and the inner shadow that gives the
// panel its recessed feel. DesktopWidget never hard-codes a silhouette — it
// just asks the shape to draw. Adding a circle or a squircle later means one
// new subclass here and one new string case in from_spec(); nothing else in
// the tree changes.
//
// The frame is not a stroke: the widget fills the whole silhouette with the
// border colour and clips the content to a smaller opening, so the frame is
// the fill left showing around it. That is what lets each shape pick its own
// inner corner radius.

namespace LumenDesktop {

    public abstract class WidgetShape : GLib.Object {

        // Extra chrome above the opening, on top of the uniform border width:
        // the folder tab for FolderShape, a plain heavier top edge otherwise.
        protected float top_extra;

        // Confine everything drawn until the matching pop() to the silhouette.
        // Implementations must push exactly one clip node.
        public abstract void push_clip(Gtk.Snapshot s, int w, int h);

        // Fill the silhouette. Called immediately after push_clip, so a plain
        // rect fill is enough for any shape — the clip does the work.
        public virtual void fill(Gtk.Snapshot s, int w, int h, Gdk.RGBA color) {
            var r = Graphene.Rect();
            r.init(0, 0, w, h);
            s.append_color(color, r);
        }

        // How far the content sits inside the silhouette, in CSS order —
        // top, right, bottom, left. The shape reports it so extra chrome on
        // one side (the folder tab) stays the shape's business alone.
        public virtual float[] frame_insets(float border) {
            return { border + top_extra, border, border, border };
        }

        // The opening the content lives in: the silhouette shrunk by the frame.
        // Implementations must push exactly one clip node.
        public abstract void push_content_clip(Gtk.Snapshot s, int w, int h, float[] frame);

        // Rects covering the silhouette, in widget-local coordinates. They
        // feed the window's input region, so a shape that doesn't fill its
        // box (the folder's tab strip) must report the parts it does — the
        // rest has to stay click-through.
        public virtual Cairo.RectangleInt[] hit_rects(int w, int h) {
            return { Cairo.RectangleInt() { x = 0, y = 0, width = w, height = h } };
        }

        // The recessed edge falloff, drawn on top of the content but still
        // inside the content clip, so it hugs the opening and not the outer
        // silhouette. Shapes with no notion of an inset shadow may leave this
        // empty.
        public abstract void inner_shadow(Gtk.Snapshot s, int w, int h, float[] frame,
                                          Gdk.RGBA color, float blur, float spread);

        // Build a shape from a widget spec's "shape" string plus its numeric
        // parameters. Unknown names fall back to a folder rather than failing
        // to place the widget at all.
        public static WidgetShape from_spec(string name, double radius,
                                            double top_extra, double tab_ratio) {
            switch (name) {
                case "folder":
                case "":
                    return new FolderShape((float) radius, (float) top_extra, (float) tab_ratio);
                case "rounded-rect":
                case "rounded-rectangle":
                    return new RoundedRectShape((float) radius, (float) top_extra);
                case "rect":
                case "square":
                    return new RoundedRectShape(0, (float) top_extra);
                case "pill":
                    // Radius resolved at draw time from the height.
                    return new RoundedRectShape(-1, (float) top_extra);
                default:
                    warning("lumen-desktop: unknown widget shape '%s', using folder", name);
                    return new FolderShape((float) radius, (float) top_extra, (float) tab_ratio);
            }
        }
    }

    // A rectangle with uniform corner radius. A negative radius means "pill" —
    // half the height, resolved per draw (same convention as lumen-osd's Pill).
    public class RoundedRectShape : WidgetShape {

        protected float radius;

        public RoundedRectShape(float radius, float top_extra = 0) {
            this.radius = radius;
            this.top_extra = top_extra;
        }

        protected float effective_radius(int w, int h) {
            if (radius < 0) return h / 2.0f;
            // Never let the radius exceed half the smaller side, or GSK draws
            // a distorted silhouette.
            return float.min(radius, float.min(w, h) / 2.0f);
        }

        private Gsk.RoundedRect rounded(int w, int h) {
            var r = Graphene.Rect();
            r.init(0, 0, w, h);
            var rr = Gsk.RoundedRect();
            rr.init_from_rect(r, effective_radius(w, h));
            return rr;
        }

        // The opening, with ONE radius on all four corners, derived from the
        // thinnest side so the frame never pinches to nothing at a corner.
        // Shrinking each corner by its own two side widths instead — what CSS
        // and Gtk.Snapshot.append_border do — leaves an asymmetric frame with
        // bulging corners on its heavy side.
        protected Gsk.RoundedRect opening(int w, int h, float[] frame) {
            float top = frame[0], right = frame[1], bottom = frame[2], left = frame[3];
            float iw = float.max(0, w - left - right);
            float ih = float.max(0, h - top - bottom);

            var r = Graphene.Rect();
            r.init(left, top, iw, ih);

            float thinnest = float.min(float.min(left, right), float.min(top, bottom));
            float inner = float.max(0, effective_radius(w, h) - thinnest);
            inner = float.min(inner, float.min(iw, ih) / 2.0f);

            var rr = Gsk.RoundedRect();
            rr.init_from_rect(r, inner);
            return rr;
        }

        public override void push_clip(Gtk.Snapshot s, int w, int h) {
            s.push_rounded_clip(rounded(w, h));
        }

        public override void push_content_clip(Gtk.Snapshot s, int w, int h, float[] frame) {
            s.push_rounded_clip(opening(w, h, frame));
        }

        public override void inner_shadow(Gtk.Snapshot s, int w, int h, float[] frame,
                                          Gdk.RGBA color, float blur, float spread) {
            if (color.alpha <= 0 || (blur <= 0 && spread <= 0)) return;
            // append_inset_shadow draws the shadow ring directly, on top of
            // whatever content has already been snapshotted inside the clip.
            s.append_inset_shadow(opening(w, h, frame), color, 0, 0, spread, blur);
        }
    }

    // The file-folder silhouette: a body rounded on all four corners with a
    // tab raised above the left part of its top edge. The opening stays a
    // plain rounded rect inside the body, so content never has to cope with a
    // non-rectangular hole.
    public class FolderShape : RoundedRectShape {

        private float tab_ratio;    // tab width as a fraction of the widget

        public FolderShape(float radius, float tab_height, float tab_ratio) {
            base(radius, tab_height);
            this.tab_ratio = tab_ratio.clamp(0.1f, 0.9f);
        }

        // Leave the body at least half the widget, or the silhouette stops
        // reading as a folder and starts reading as a lopsided box.
        private float tab_height(int h) {
            return float.min(top_extra, h / 2.0f);
        }

        // The step off the tab is a short slant, as on a real folder tab.
        private float slant(int h) { return tab_height(h) * 0.55f; }

        private float tab_width(int w, int h) {
            float r = corner_radius(w, h);
            return (w * tab_ratio).clamp(2 * r + slant(h), w - 2 * r - slant(h));
        }

        // The body's corners, not the widget's: the tab eats into the height.
        private float corner_radius(int w, int h) {
            return float.min(effective_radius(w, h), (h - tab_height(h)) / 2.0f);
        }

        // Walked clockwise from the left edge just below the tab's top-left
        // corner. html_arc_to() is canvas/CSS arcTo — it rounds the corner
        // between the current point, the corner and the next point, concave
        // ones included, which is the join a rounded rect can't express.
        private Gsk.Path outline(int w, int h) {
            float th = tab_height(h);
            float r = corner_radius(w, h);
            float sl = slant(h);
            float step_r = float.min(r * 0.5f, th * 0.5f);
            float tab_w = tab_width(w, h);

            var b = new Gsk.PathBuilder();
            b.move_to(0, r);                                  // left edge, below the tab corner
            b.html_arc_to(0, 0, tab_w, 0, r);                 // tab top-left
            b.html_arc_to(tab_w, 0, tab_w + sl, th, step_r);  // tab top-right
            b.html_arc_to(tab_w + sl, th, w, th, step_r);     // concave step onto the body
            b.html_arc_to(w, th, w, h, r);                    // body top-right
            b.html_arc_to(w, h, 0, h, r);                     // bottom-right
            b.html_arc_to(0, h, 0, 0, r);                     // bottom-left
            b.close();
            return b.to_path();
        }

        public override void push_clip(Gtk.Snapshot s, int w, int h) {
            s.push_fill(outline(w, h), Gsk.FillRule.WINDING);
        }

        public override void push_content_clip(Gtk.Snapshot s, int w, int h, float[] frame) {
            s.push_rounded_clip(opening(w, h, frame));
        }

        public override Cairo.RectangleInt[] hit_rects(int w, int h) {
            int th = (int) tab_height(h);
            return {
                Cairo.RectangleInt() { x = 0, y = th, width = w, height = h - th },
                Cairo.RectangleInt() { x = 0, y = 0,
                                       width = (int) (tab_width(w, h) + slant(h)),
                                       height = th }
            };
        }
    }
}
