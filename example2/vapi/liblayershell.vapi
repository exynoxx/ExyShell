[CCode (cheader_filename = "liblayershell.h")]
namespace LayerShell {
    [CCode (cname = "EDGE", cprefix = "", has_type_member = false)]
    public enum Edge {
        TOP,
        BOTTOM
    }

    [CCode (cname = "init_layer_shell")]
    public int init(string layer_name, int width, int height, Edge edge);
    
    [CCode (cname = "egl_swap_buffers")]
    public void swap_buffers();

    [CCode (cname = "get_wl_display")]
    public unowned Wl.Display get_wl_display();

    [CCode (cname = "wl_display_dispatch")]
    public int display_dispatch(Wl.Display display);

    [CCode (cname = "destroy_layer_shell")]
    public void destroy();

    [CCode (cname = "dk_mouse_info", destroy_function = "", has_type_member = false)]
    [Compact]
    public class MouseInfo {
        public double mouse_x;
        public double mouse_y;
        public uint32 mouse_buttons;
    }

    [CCode (cname = "seat_mouse_info")]
    public unowned MouseInfo mouse_info();
}