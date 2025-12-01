/*  public class Interactable {

    public int grid_x;
    public int grid_y;

    public int width;
    public int height;

    private bool hovered;
    private bool clicked;

    public override void mouse_up (ref bool redraw){
        clicked = false;
        redraw = true;
        if(hovered) launch_app();
    }

    public void mouse_down(ref bool redraw){
        if(hovered) {
            if(!clicked) redraw = true;
            clicked = true;
        }
    }

    public void mouse_move(double mouse_x, double mouse_y, ref bool redraw){
        int x = grid_x;
        int y = grid_y;
        int w = grid_x + width;
        int h = grid_y + height;
        
        var hover_initial = hovered;

        hovered = (mouse_x >= x && mouse_x <= w && mouse_y >= y && mouse_y <= h);
        if(hovered != hover_initial) redraw = true;
    }
}  */