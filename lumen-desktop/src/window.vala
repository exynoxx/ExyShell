// The desktop widget layer surface.
//
// One per monitor, full-output, on the BOTTOM layer: above wf-background's
// wallpaper, below every normal window — so opening an app covers the widgets
// and closing it re-exposes them, with no compositor involvement.
//
// Two things make a full-output BOTTOM surface safe here:
//
//  1. The Wayland input region is clipped to the widgets' rectangles (see
//     update_input_region, modelled on lumen-panel/src/panel_window.vala).
//     Without it this surface would eat every click on empty desktop and
//     break the panel's Win+D peek dismissal.
//
//  2. lumen-drawer also lives on BOTTOM, but the curtain/slide peek plugins
//     keep its scene node disabled except during a peek — and during a peek
//     they disable *our* node (their widget_app_id option). The two are never
//     enabled at the same time, so their relative stacking never matters.

private const string DESKTOP_CSS = """
window.lumen-desktop-root {
    background: transparent;
}
.fb-column-sep {
    background: alpha(#ffffff, 0.08);
}
.fb-empty {
    color: alpha(#ffffff, 0.45);
    font-size: 13px;
}
""";

namespace LumenDesktop {

    public class DesktopWindow : Gtk.ApplicationWindow {

        private WidgetHost host;
        private Cairo.Region? last_region = null;

        public DesktopWindow(Gtk.Application app, Gdk.Monitor? monitor, WidgetSpec[] specs) {
            Object(application: app);

            GtkLayerShell.init_for_window(this);
            GtkLayerShell.set_namespace(this, "lumen-desktop");
            if (monitor != null) GtkLayerShell.set_monitor(this, monitor);
            // BOTTOM, not BACKGROUND: wf-background's wallpaper surface lives on
            // BACKGROUND and tends to map after us, which would hide the
            // widgets. BOTTOM still renders below every regular window.
            GtkLayerShell.set_layer(this, GtkLayerShell.Layer.BOTTOM);
            GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.LEFT,   true);
            GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.RIGHT,  true);
            GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.TOP,    true);
            GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.BOTTOM, true);
            // Never consume an exclusive zone — windows must size as if the
            // desktop layer were not there.
            GtkLayerShell.set_exclusive_zone(this, 0);
            // ON_DEMAND: keys arrive only after a click into a widget, and go
            // back to apps as soon as one is focused. NONE would make the file
            // browser's arrow-key navigation dead.
            GtkLayerShell.set_keyboard_mode(this, GtkLayerShell.KeyboardMode.ON_DEMAND);

            decorated = false;
            add_css_class("lumen-desktop-root");
            install_css();

            host = new WidgetHost(specs);
            set_child(host);

            host.layout_changed.connect(update_input_region);
            this.map.connect(update_input_region);
            notify["default-width"].connect(update_input_region);
        }

        private static bool css_installed = false;
        private static void install_css() {
            if (css_installed) return;
            css_installed = true;
            var css = new Gtk.CssProvider();
            css.load_from_string(DESKTOP_CSS);
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(), css,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        // Restrict pointer input to the widgets. Everything else on this
        // full-output surface is click-through.
        private void update_input_region() {
            var gdk_surface = get_surface();
            if (gdk_surface == null) return;

            var region = new Cairo.Region();
            foreach (var r in host.widget_rects()) {
                region.union_rectangle(r);
            }

            // Skip redundant Wayland roundtrips — size-allocate fires per
            // frame during an output reconfigure.
            if (last_region != null && last_region.equal(region)) return;
            last_region = region.copy();
            gdk_surface.set_input_region(region);
        }
    }
}
