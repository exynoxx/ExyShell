using DrawKit;
using GLES2;
/*  DEVICE  TYPE      STATE      CONNECTION
wlp2s0  wifi      connected  HomeWiFi
eth0    ethernet  unavailable --


# Overall connectivity state
nmcli networking connectivity
# Wi-Fi status
nmcli device status*/

public class Tray {

    public const int MARGIN_RIGHT = 20;
    public const int TRAY_HEIGHT = HEIGHT - 12;
    public const int MARGIN_TOP = (HEIGHT - TRAY_HEIGHT)/2;
    public const int SPACING = 20;

    private unowned Context ctx;
    private int screen_width;

    private TrayIcon[] trays;
    private int base_width;
    private int width;
    private int x;
    private int y;
    private bool hovered;

    private Transition expand_animation;

    public Tray(Context ctx, int screen_width){
        this.ctx = ctx;
        this.screen_width = screen_width;

        //calc width
        string[] names = {"wifi", "mid", "close"};
        foreach (var name in names) {
            var tray = new TrayIcon(name, MARGIN_TOP, name);
            base_width += SPACING + tray.width;
            trays += tray;
        }
        base_width += SPACING;
        width = base_width;
        
        //calc x's
        this.x = screen_width - width - MARGIN_RIGHT;

        var current_x = this.x + SPACING;
        foreach (var tray in trays){
            tray.set_position(current_x);
            current_x += tray.width + SPACING;
        }

        expand_animation = new TransitionEmpty();
    }


    public void on_mouse_down(){
        
    }

    public void on_mouse_up(){
        
    }
    
    public void on_mouse_motion(int mouse_x, int mouse_y){
        var hover_initial = hovered;

        hovered = (mouse_x >= x && mouse_y >= 0);
        if(hovered != hover_initial) 
        {
            expand_animation = (hovered) 
            ? new Transition1D(0, &width, 300, 1)
            : new Transition1D(0, &width, base_width, 1);

            animations.add(expand_animation);
        }

        foreach(var tray in trays){
            tray.mouse_motion(mouse_x,mouse_y);
        }
    }

    public void on_mouse_leave(){
        if(width > base_width){
            expand_animation = new Transition1D(0, &width, base_width, 1);
            animations.add(expand_animation);
        }
        redraw = true;
    }

    public void render(){
        if(!expand_animation.finished){
            this.x = screen_width - width - MARGIN_RIGHT;
        }

        ctx.draw_rect_rounded(this.x, MARGIN_TOP, width, TRAY_HEIGHT, 24, {0.15f,0.15f,0.15f,1});
        foreach(var t in trays){
            t.render(ctx);
        }
    }

}