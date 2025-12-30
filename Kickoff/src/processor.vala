using DrawKit;
using WLHooks;
using GLES2;
using Gee;

public class Processor {
    private Context ctx;
    private AppEntry[] apps;

    private SearchBar searchbar;
    private SearchDb searchDb;

    private GridView main_grid;
    private SearchGridView search_grid;
    private unowned IGrid grid;

    private float bg_a;

    public Processor(int screen_width, int screen_height) {
        WLHooks.init_layer_shell("Kickoff-overlay", screen_width, screen_height, UP | LEFT | RIGHT | DOWN, false);

        ctx = Context.Init_with_groups(screen_width, screen_height, 2);

        var icon_theme = Utils.System.get_current_theme();
        var icon_paths = Utils.Icon.find_icon_paths(icon_theme, 96);
        print("using icon theme: %s. Num icons: %i\n", icon_theme, icon_paths.size);

        var desktop_files = Utils.System.get_desktop_files();
        print("#desktop files: %i\n", desktop_files.length);

        var imported_names = new HashSet<string>();

        foreach (var desktop in desktop_files){
            var entries = Utils.Config.parse(desktop, "Desktop Entry");

            if (entries["Icon"] == null || entries["Exec"] == null || entries["Name"] == null) continue;

            var name = entries["Name"];
            var icon = entries["Icon"];
            var exec = entries["Exec"];

            if(!icon_paths.has_key(icon))
                continue;
            
            if(imported_names.contains(name)) 
                continue;
            
            imported_names.add(name);

            var icon_path = icon_paths[icon];
            apps += new AppEntry(name, icon_path, exec);
        }

        print("Apps: %i\n", apps.length);

        searchDb = new SearchDb(apps, screen_width, screen_height);
        searchbar = new SearchBar(ctx, screen_width);

        main_grid = new GridView(ctx, apps, screen_width, screen_height);
        search_grid = new SearchGridView(ctx, screen_width, screen_height);
        grid = main_grid;

        Main.animations.add(new Transition1D(0, &bg_a, 0.8f, 3));
    }

    /*  public void show_overlay (){
        WLHooks.init_layer_shell("Kickoff-overlay", screen_width, screen_height, UP | LEFT | RIGHT | DOWN, false);
    }  */

    public void mouse_move(int mouse_x, int mouse_y) {
        grid.mouse_move(mouse_x, mouse_y);
    }

    public void mouse_down() {
        grid.mouse_down();
    }
    public void mouse_up() {
        grid.mouse_up();
    }

    public void key_down(uint32 key){
        if(key == 65307){
            WLHooks.destroy();
            Process.exit (0);
        }

        searchDb.on_key(key);

        if(searchDb.active){
            grid = (IGrid) search_grid;
            search_grid.add(searchDb.filtered, searchDb.size);
        } else {
            grid = (IGrid) main_grid;
        }

        grid.key_down(key);
    }
    
    public void render() {
        ctx.set_bg_color(DrawKit.Color(){ r = 0, g =  0, b = 0, a = bg_a });
        
        ctx.begin_frame();

        searchbar.render(searchDb.get_search());
        grid.render();

        ctx.end_frame();
    }

    //TODO main loop
    /*  public void main_loop(){

    }  */
}