using DrawKit;
using Gee;

public class Panel {

    public const int HEIGHT = 60;
    public const int UNDERLINE_HEIGHT = 5;
    public const int APP_UNDERLINE_HEIGHT = HEIGHT-UNDERLINE_HEIGHT;

    private int width;
    private Gee.List<App> entries;
    private int active_idx;

    private Context ctx;

    public Panel(int screen_width){
        WLHooks.init_layer_shell("panel", screen_width, HEIGHT, BOTTOM, true);

        ctx = new DrawKit.Context(screen_width, HEIGHT);
        ctx.set_bg_color(DrawKit.Color(){r=0,g=0,b=0,a=0});

        entries = new ArrayList<App>();
        entries.add(new App("--","--",0));

    }

    public void on_window_new(string app_id, string title){
        entries.add(new App(app_id, title, entries.size));
    }

    public void on_window_rm(string app_id, string title){
        for (var i = 0; i < entries.size ; i++){
            var entry = entries[i];
            if(entry.app_id == app_id && entry.title == title){
                entry.free();
                entries.remove (entry);
                redraw = true;
            }
        }

        for (var i = 1; i < entries.size ; i++){
            entries[i].reset_order(i);
        }
    }

    public void on_window_focus(string app_id, string title){
        var i = 0;
        foreach(var entry in entries){
            if(entry.app_id == app_id && entry.title == title){
                active_idx = i;
                redraw = true;
                return;
            }
            i++;
        }
    }

    public void on_mouse_down(){
        foreach(var app in entries){
            if(app.hovered && !app.clicked){
                app.clicked = true;
                app.on_click();
            }
        }
    }

    public void on_mouse_up(){
        foreach(var app in entries){
            app.clicked = false;
        }
    }
    
    public void on_mouse_motion(double x, double y){
        foreach(var app in entries){
            app.mouse_motion(x,y);
        }
    }

    public void on_mouse_leave(){
        foreach(var app in entries){
            app.hovered = false;
        }
        redraw = true;
    }

    public void render(){
        ctx.begin_frame();

        //launcher
        entries[0].render(ctx);

        //sep
        ctx.draw_rect(App.WIDTH, 10, 2, App.HEIGHT-20, Color(){r=0,g=0,b=0,a=1});

        //open programs
        for(var i = 1; i<entries.size; i++){
            entries[i].render(ctx);
        }

        //underline
        float shade = 0.15f;
        ctx.draw_rect(0, App.HEIGHT, App.WIDTH, APP_UNDERLINE_HEIGHT, Color(){r=shade,g=shade,b=shade,a=1});

        //active
        if(active_idx >= 0){
            var color = Color(){r=0,g=0.17f,b=0.9f,a=1};
            ctx.draw_rect(active_idx*App.WIDTH, App.HEIGHT, App.WIDTH, APP_UNDERLINE_HEIGHT, color);
        }

        ctx.end_frame();
    }
}