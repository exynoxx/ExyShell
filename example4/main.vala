using Gtk;
using Gdk;
using GtkLayerShell;

public struct Program {
    public string app_id;
    public string title;
    public Gdk.Texture tex;
}

public class DrawingArea : Gtk.DrawingArea {
    private Gee.ArrayList<Program?> programs;
    private int active_idx = -1;
    private int hover_idx = -1;
    private const int BOX_WIDTH = 64;
    private const int BOX_HEIGHT = 48;
    private const int ICON_SIZE = 32;
    private const int UNDERLINE_HEIGHT = 3;

    Gdk.Texture tex;

    public Gdk.Texture? load_icon(string icon_name, int size = 32) {
        // Method 1: Load from icon theme
        var icon_theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default());
        var icon_paintable = icon_theme.lookup_icon(
            icon_name,
            null,  // fallbacks
            size,
            1,     // scale
            Gtk.TextDirection.NONE,
            Gtk.IconLookupFlags.FORCE_REGULAR
        );
        
        if (icon_paintable != null) {
            var file = icon_paintable.get_file();
            if (file != null) {
                try {
                    return Gdk.Texture.from_file(file);
                } catch (Error e) {
                    warning("Failed to load icon: %s", e.message);
                }
            }
        }
        
        return null;
    }
    
    public DrawingArea() {
        programs = new Gee.ArrayList<Program?>();
        
        set_content_width(1920);
        set_content_height(BOX_HEIGHT);
        
        // Add motion controller for hover
        var motion = new Gtk.EventControllerMotion();
        motion.motion.connect((x, y) => {
            int old_hover = hover_idx;
            hover_idx = (int)(x / BOX_WIDTH);
            if (hover_idx >= programs.size) {
                hover_idx = -1;
            }
            if (old_hover != hover_idx) {
                queue_draw();
            }
        });
        motion.leave.connect(() => {
            hover_idx = -1;
            queue_draw();
        });
        add_controller(motion);
        
        // Add click controller
        var click = new GestureClick();
        click.pressed.connect((n_press, x, y) => {
            int clicked_idx = (int)(x / BOX_WIDTH);
            if (clicked_idx >= 0 && clicked_idx < programs.size) {
                print("Clicked on: %s\n", programs[clicked_idx].title);
                active_idx = clicked_idx;
                // TODO: Focus window with programs[clicked_idx].id
                queue_draw();
            }
        });
        add_controller(click);

        tex = load_icon("firefox", 32);
        add_program("firefox", "fixrefox", tex);
    }
    
    public void add_program(string title, string app_id, Gdk.Texture? texture = null) {
        programs.add(Program() {
            title = title,
            app_id = app_id,
            tex = texture
        });
        queue_draw();
    }
    
    public void remove_program(uint32 id) {
        /*  for (int i = 0; i < programs.size; i++) {
            if (programs[i].id == id) {
                programs.remove_at(i);
                if (active_idx == i) {
                    active_idx = -1;
                } else if (active_idx > i) {
                    active_idx--;
                }
                queue_draw();
                break;
            }
        }  */
    }
    
    public void set_active_program(uint32 id) {
       /*   for (int i = 0; i < programs.size; i++) {
            if (programs[i].id == id) {
                active_idx = i;
                queue_draw();
                break;
            }
        }  */
    }
    
    // Override snapshot method
    public override void snapshot(Gtk.Snapshot snapshot) {
        int width = get_width();
        int height = get_height();
        
        // Background
        var bg_rect = Graphene.Rect() {
            origin = { 0, 0 },
            size = { width, height }
        };
        var bg_color = RGBA();
        bg_color.parse("#1e1e2e");
        bg_color.alpha = 0.5f;
        snapshot.append_color(bg_color, bg_rect);
        
        // Draw taskbar items
        float x_offset = 0;
        for (int i = 0; i < programs.size; i++) {
            // Box background (hover effect)
            if (i == hover_idx) {
                var hover_rect = Graphene.Rect() {
                    origin = { x_offset, 0 },
                    size = { BOX_WIDTH, BOX_HEIGHT - UNDERLINE_HEIGHT }
                };
                var hover_color = RGBA();
                hover_color.parse("#ffffff");
                hover_color.alpha = 0.2f;
                snapshot.append_color(hover_color, hover_rect);
            }
            
            // Draw icon/texture
            var program = programs[i];
            if (program.tex != null) {
                var padding_side = (BOX_WIDTH - ICON_SIZE) / 2.0f;
                var padding_top = (BOX_HEIGHT - UNDERLINE_HEIGHT - ICON_SIZE) / 2.0f;
                
                var icon_rect = Graphene.Rect() {
                    origin = { x_offset + padding_side, padding_top },
                    size = { ICON_SIZE, ICON_SIZE }
                };
                snapshot.append_texture(program.tex, icon_rect);
            } else {
                // Fallback: draw app_id text
                var text = program.app_id.length > 4 ? 
                    program.app_id.substring(0, 4) : program.app_id;
                draw_text_centered(snapshot, text, 
                    x_offset + BOX_WIDTH / 2, 
                    (BOX_HEIGHT - UNDERLINE_HEIGHT) / 2, 
                    "#cdd6f4");
            }
            
            x_offset += BOX_WIDTH;
        }
        
        // Bottom shade line
        var shade_rect = Graphene.Rect() {
            origin = { 0, BOX_HEIGHT - UNDERLINE_HEIGHT },
            size = { width, UNDERLINE_HEIGHT }
        };
        var shade_color = RGBA();
        shade_color.parse("#262626");
        snapshot.append_color(shade_color, shade_rect);
        
        // Active indicator
        if (active_idx >= 0 && active_idx < programs.size) {
            var active_rect = Graphene.Rect() {
                origin = { active_idx * BOX_WIDTH, BOX_HEIGHT - UNDERLINE_HEIGHT },
                size = { BOX_WIDTH, UNDERLINE_HEIGHT }
            };
            var active_color = RGBA();
            active_color.parse("#0030e8");
            snapshot.append_color(active_color, active_rect);
        }
    }
    
    private void draw_text_centered(Gtk.Snapshot snapshot, string text, float x, float y, string color_str) {
        var color = RGBA();
        color.parse(color_str);
        
        var layout = create_pango_layout(text);
        int text_width, text_height;
        layout.get_pixel_size(out text_width, out text_height);
        
        snapshot.save();
        var point = Graphene.Point() {
            x = x - text_width / 2.0f,
            y = y - text_height / 2.0f
        };
        snapshot.translate(point);
        snapshot.append_layout(layout, color);
        snapshot.restore();
    }
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

