using Gee;
using DrawKit;

public class PageButton {

    private int x;
    private int y;
    private string label;

    public PageButton (int x, int y, string label){
        this.x = x;
        this.y = y;
        this.label = label;
    }
    
    public void render(Context ctx) {
        //ctx.draw_circle(x,y, (Color) {0.3f,0.3f,0.3f,1f});
        ctx.draw_text(label, x, y+5, 15);
    }
}


public class Navigation {

    private ArrayList<PageButton> _pages;

    public Navigation(){
        _pages = new ArrayList<PageButton>();
    }

    public void AddPage(){

    }

    public void render(Context ctx) {
        foreach (var page in _pages){
            page.render(ctx);
        }
    } 



}


