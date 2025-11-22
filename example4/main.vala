using Gtk;
using Gdk;
using GtkLayerShell;

public struct Program {
    public string app_id;
    public string title;
    public Gdk.Texture tex;
}

public class LayerShellBar : Gtk.ApplicationWindow {
    private DrawingArea drawing_area;
    
    public LayerShellBar(Gtk.Application app) {
        Object(application: app);
        
        // Initialize layer shell
        GtkLayerShell.init_for_window(this);
        
        // Configure layer shell
        GtkLayerShell.set_layer(this, GtkLayerShell.Layer.TOP);
        GtkLayerShell.set_namespace(this, "custom-bar");
        
        // Anchor to top edge
        GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.TOP, false);
        GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.LEFT, true);
        GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.RIGHT, true);
        GtkLayerShell.set_anchor(this, GtkLayerShell.Edge.BOTTOM, true);
        
        // Set exclusive zone
        GtkLayerShell.set_exclusive_zone(this, 32);

        // In your window class or after window is realized
       /*   var gdk_display = this.get_display(); // or Gdk.Display.get_default()
    
        // You need to use the Wayland-specific functions
        // This requires gdk-wayland bindings
        #if GDK_WINDOWING_WAYLAND
        var wl_display = Gdk.Wayland.Display.get_wl_display(gdk_display);
        #endif  */

        //print("wl_display %A", wl_display);

        // Create custom bar

        drawing_area = new DrawingArea();
        
        // Add motion controller to the drawing area, not the window
        var motion = new Gtk.EventControllerMotion();
        motion.motion.connect((x, y) => {
            print("Pointer at %.1f, %.1f relative to widget\n", x, y);
        });  // Use proper signal connection
        drawing_area.add_controller(motion);
        
        set_child(drawing_area);
    }
}

public class Application : Gtk.Application {
    public Application() {
        Object(application_id: "com.example.layershellbar", flags: ApplicationFlags.FLAGS_NONE);
    }
    
    protected override void activate() {
        var window = new LayerShellBar(this);
        window.present();
    }

    public static int main(string[] args) {
        var app = new Application();
    
        return app.run(args);
    }
}

