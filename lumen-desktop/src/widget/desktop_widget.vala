// Base class for everything that can live on the desktop.
//
// A DesktopWidget is chrome + one content child. The chrome (silhouette,
// background fill, inner edge shadow) is entirely delegated to a WidgetShape,
// so a subclass only ever supplies content. v1 has one subclass
// (FileBrowserWidget); clock / weather / app-chooser widgets slot in the same
// way and need to override nothing but set_content().

namespace LumenDesktop {

    public abstract class DesktopWidget : Gtk.Widget {

        public WidgetShape shape { get; construct set; }
        public WidgetSettings settings { get; construct set; }

        public Gdk.RGBA background { get; set; }
        public Gdk.RGBA shadow_color { get; set; }
        public float shadow_blur { get; set; default = 18.0f; }
        public float shadow_spread { get; set; default = 1.0f; }

        private Gtk.Widget? content = null;

        construct {
            // Content is clipped to the silhouette, so a child that overflows
            // (a scrolled column strip, say) never leaks past the corners.
            overflow = Gtk.Overflow.HIDDEN;
            background = { 0.10f, 0.11f, 0.13f, 0.88f };
            shadow_color = { 0.0f, 0.0f, 0.0f, 0.45f };
        }

        // Subclasses call this exactly once, from their constructor.
        protected void set_content(Gtk.Widget child) {
            if (content != null) content.unparent();
            content = child;
            content.set_parent(this);
        }

        protected Gtk.Widget? get_content() { return content; }

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

            int cmin, cnat, cminb, cnatb;
            content.measure(orientation, for_size, out cmin, out cnat, out cminb, out cnatb);
            minimum = cmin;
            natural = cnat;
        }

        public override void size_allocate(int width, int height, int baseline) {
            if (content == null) return;
            content.allocate(width, height, baseline, null);
        }

        public override void snapshot(Gtk.Snapshot s) {
            int w = get_width();
            int h = get_height();
            if (w <= 0 || h <= 0) return;

            shape.push_clip(s, w, h);
            shape.fill(s, w, h, background);
            if (content != null) snapshot_child(content, s);
            shape.inner_shadow(s, w, h, shadow_color, shadow_blur, shadow_spread);
            s.pop();
        }
    }
}
