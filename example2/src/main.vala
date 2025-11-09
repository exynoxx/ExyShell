using LayerShell;
using Graphene;

public static int main(string[] args) {
    
    int width = 1920;
    int height = 50;

    LayerShell.init("panel", width, height, BOTTOM);
    unowned var display = LayerShell.get_wl_display();

    while (LayerShell.display_dispatch(display) != -1) {

        
        LayerShell.swap_buffers();
    }

    return 0;
}