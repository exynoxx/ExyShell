using GLib;

public class SearchDb {

    const int64 REPEAT_INTERVAL_MS = 50;
    const int BACKSPACE_KEYCODE = 8;

    int64 last_erase_time = 0; // in milliseconds
    bool first_press = true;

    private string[] strings;
    public StringBuilder current_search;
    private const string standard_label = "Search";

    public SearchDb(AppEntry[] apps) {
        foreach (var app in apps){
            strings += app.name;
        }

        current_search = new StringBuilder();
    }

    public void key_down(char key){
        print("key down\n");
        if (first_press) {
            first_press = false;

            on_key(key);
            return;
        }

        if (get_elapsed() < REPEAT_INTERVAL_MS) {
            return; // too early, skip
        }

        on_key(key);

    }

    public void key_up(char key){
        print("key up\n");

        first_press = true;
    }

    private void on_key(char key){
        if(key == 8) //backspace
            if(current_search.len > 0)
                current_search.erase(current_search.len - 1, 1);
        else 
            current_search.append_c(key);
        
        Main.queue_redraw();
    }

    public string get_search(){
        if(current_search.len == 0) {
            return standard_label;
        } 
        return current_search.str;
    }

    private int64 get_elapsed(){
        int64 now = get_monotonic_time() / 1000; // microseconds → ms
        var elapsed = now - last_erase_time;
        last_erase_time = now;
        return elapsed;
    }
}