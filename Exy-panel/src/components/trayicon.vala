using DrawKit;
using GLES2;

public class TrayIcon {

    private const string base_path = "/home/nicholas/Dokumenter/layer-shell-experiments/Exy-panel/src/res/";
    private const int ICON_SIZE = 32;
    private const int NARGIN_TOP = (Tray.TRAY_HEIGHT - ICON_SIZE)/2;

    private string id;
    private GLuint tex;
    private bool hovered;
    
    private int x;
    private int y;
    private int hover_x;
    private int hover_y;

    public int width {get; private set;}

    public TrayIcon(string id, int y, string icon){
        this.id = id;
        this.x = x;
        this.y = y + NARGIN_TOP;
        this.hover_x = x + ICON_SIZE/2;
        this.hover_y = this.y + ICON_SIZE/2;
        load(icon);
        width = ICON_SIZE;
    }

    public void set_position(int x){
        this.x = x;
        this.hover_x = x + ICON_SIZE/2;
    }

    public void load(string icon){

        var path = Path.build_filename(base_path, icon+".svg");

        var image = DrawKit.image_from_svg(path,ICON_SIZE,ICON_SIZE);
        if(image == null){
            print("Launcher icon not found");
            return;
        }

        tex = DrawKit.texture_upload(*image);
    }

    public void free(){
        DrawKit.texture_free(tex);
    }

    public void mouse_motion(int mouse_x, int mouse_y){
        int w = x + width;
        int h = y + width;
        
        var hover_initial = hovered;

        hovered = (mouse_x >= x && mouse_x <= w && mouse_y >= y && mouse_y <= h);
        if(hovered != hover_initial) 
            redraw = true;
    }

    public void render(Context ctx){
        
        if(hovered){
            ctx.draw_circle(hover_x, hover_y, 24, {1,1,1,1});
            ctx.set_tex_color({0,0,0,1});
            ctx.draw_texture(tex, x, y, ICON_SIZE, ICON_SIZE);
            ctx.set_tex_color({1,1,1,1});
            return;

        } 

        ctx.draw_texture(tex, x, y, ICON_SIZE, ICON_SIZE);
    }
}