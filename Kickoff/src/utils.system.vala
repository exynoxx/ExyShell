using GLib;
using Gee;

namespace Utils {

    public class System {
        public static string[] get_xdg_data_dirs() {
            var dirs = new Gee.ArrayList<string>();
            
            // Add user data directory first
            string user_data_dir = Environment.get_user_data_dir();
            dirs.add(user_data_dir);
            
            // Add system data directories
            string system_dirs = Environment.get_variable("XDG_DATA_DIRS");
            if (system_dirs == null || system_dirs == "") {
                system_dirs = "/usr/local/share:/usr/share";
            }
            
            foreach (string dir in system_dirs.split(":")) {
                if (dir != "") {
                    dirs.add(dir);
                }
            }
            
            return dirs.to_array();
        }

        public static string[] get_icon_theme_dirs() {
            var dirs = new Gee.ArrayList<string>();
            
            // User icon directory
            string home = Environment.get_home_dir();
            dirs.add(Path.build_filename(home, ".icons"));
            dirs.add(Path.build_filename(home, ".local", "share", "icons"));
            
            // System icon directories
            string[] data_dirs = get_xdg_data_dirs();
            foreach (string data_dir in data_dirs) {
                dirs.add(Path.build_filename(data_dir, "icons"));
            }
            
            dirs.add("/usr/share/pixmaps");
            
            return dirs.to_array();
        }

        public static string get_current_theme() {
            var gtk_settings_file = Environment.get_home_dir() + "/.config/gtk-4.0/settings.ini";
            var kde_settings_file = Environment.get_home_dir() + "/.config/kdeglobals";
    
            var gtk_settings = Utils.Config.parse(gtk_settings_file, "Settings");
            if( gtk_settings != null && gtk_settings.has_key("gtk-icon-theme-name"))
                return gtk_settings["gtk-icon-theme-name"];
            
            var kde_settings = Utils.Config.parse(kde_settings_file, "Icons");
            if (kde_settings != null && kde_settings.has_key("Theme"))
                return kde_settings["Theme"];

            return "hicolor";
        }

        public static string[] get_desktop_files() {
            var files = new Gee.ArrayList<string>();
            foreach (var data_dir in get_xdg_data_dirs()) {
                string apps_dir = Path.build_filename(data_dir, "applications");
                try {
                    Dir? dir = Dir.open(apps_dir);

                    if (dir == null)
                        continue; // skip non-existent dirs

                    //print("get_desktop_files trying %s\n", data_dir);

                    string? name;
                    while ((name = dir.read_name()) != null) {
                        if (!name.has_suffix(".desktop"))
                            continue;

                        string filepath = Path.build_filename(apps_dir, name);
                        files.add(filepath);
                    }
                } catch(FileError e){
                    continue;
                }
            }

            return files.to_array();
        }
    }

    public class Find {
        public static string? find_icon_theme_base(string theme_name) {
            foreach (var base_dir in System.get_icon_theme_dirs()) {
                string theme_dir = Path.build_filename(base_dir, theme_name);
        
                // Check if directory exists and has index.theme
                if (FileUtils.test(theme_dir, FileTest.IS_DIR)) {
                    string index_file = Path.build_filename(theme_dir, "index.theme");
                    if (FileUtils.test(index_file, FileTest.EXISTS)) {
                        return theme_dir;
                    }
                }
            }
        
            // Theme not found
            return null;
        }

        public static HashMap<string, string> find_icon_paths(string theme_name, int size = 48) {
            var result = new HashMap<string, string>();
            
            // Find theme base directory
            string? theme_base = find_icon_theme_base(theme_name);
            if (theme_base == null) {
                return result;
            }
            
            // Common size directories to check
            string[] size_variants = {
                @"$(size)x$(size)",
                @"$(size)x$(size)@2x",
                "scalable"
            };
            
            // Common subdirectories where icons are found
            string[] categories = {
                "apps",
                "applications",
                "actions",
                "places",
                "panel",
                "mimetypes",
                "devices",
                "categories",
                "emblems",
                "status"
            };
            
            // Icon file extensions
            string[] extensions = { ".png", ".svg", ".jpg", ".jpeg" };
            
            foreach (var size_dir in size_variants) {
                foreach (var category in categories) {
                    string dir_path = Path.build_filename(theme_base, size_dir, category);
                    
                    if (!FileUtils.test(dir_path, FileTest.IS_DIR)) {
                        continue;
                    }
                    
                    try {
                        var directory = Dir.open(dir_path);
                        string? filename;
                        
                        while ((filename = directory.read_name()) != null) {
                            // Check if file has a valid icon extension
                            foreach (var ext in extensions) {
                                if (filename.has_suffix(ext)) {
                                    // Extract icon name without extension
                                    string icon_name = filename.substring(0, filename.length - ext.length);
                                    
                                    // Only add if not already found (prefer earlier size variants)
                                    if (!result.has_key(icon_name)) {
                                        string full_path = Path.build_filename(dir_path, filename);
                                        result[icon_name] = full_path;
                                    }
                                    break;
                                }
                            }
                        }
                    } catch (FileError e) {
                        // Skip directories we can't read
                        continue;
                    }
                }
            }
            
            return result;
        }
/*  
        public static string? lookup_icon(string icon_name, string theme_name, int size = 48) {
            var dirs = get_icon_dirs();
            var contexts = { "apps", "actions", "devices", "places" };
            var exts = { ".png", ".svg", ".xpm" };
    
            foreach (var base_dir in dirs) {
                string theme_dir = Path.build_filename(base_dir, theme_name);
                if (!FileUtils.test(theme_dir, FileTest.IS_DIR))
                    continue;
    
                foreach (var context in contexts) {
                    string size_dir = Path.build_filename(theme_dir, "%dx%d".printf(size, size), context);
                    if (FileUtils.test(size_dir, FileTest.IS_DIR)) {
                        foreach (var ext in exts) {
                            string candidate = Path.build_filename(size_dir, icon_name + ext);
                            if (FileUtils.test(candidate, FileTest.EXISTS))
                                return candidate;
                        }
                    }
    
                    // scalable icons
                    string scalable_dir = Path.build_filename(theme_dir, "scalable", context);
                    if (FileUtils.test(scalable_dir, FileTest.IS_DIR)) {
                        foreach (var ext in exts) {
                            string candidate = Path.build_filename(scalable_dir, icon_name + ext);
                            if (FileUtils.test(candidate, FileTest.EXISTS))
                                return candidate;
                        }
                    }
                }
    
                // index.theme Inherits fallback could be parsed here (optional)
            }
    
            // last-resort fallback
            foreach (var ext in exts) {
                string fallback = Path.build_filename("/usr/share/pixmaps", icon_name + ext);
                if (FileUtils.test(fallback, FileTest.EXISTS))
                    return fallback;
            }
    
            return null; // icon not found
        }  */
    }
    
    // Find icon file from icon name
   /*   public static string? find_icon_path(string icon_name, int size = 32) {

        var theme = get_current_icon_theme();

        // If it's already an absolute path, return it
        if (Path.is_absolute(icon_name)) {
            if (FileUtils.test(icon_name, FileTest.EXISTS)) {
                return icon_name;
            }
        }
        
        string[] icon_dirs = get_icon_theme_dirs();
        string[] extensions = { ".png", ".svg", ".xpm" };
        
        // Search in theme directories
        foreach (string icon_dir in icon_dirs) {
            // Try themed icon first
            string[] size_dirs = {
                @"$(size)x$(size)",
                "48x48",
                "32x32",
                "24x24",
                "16x16",
                "scalable",
            };
            
            foreach (string size_dir in size_dirs) {
                foreach (string ext in extensions) {
                    string icon_path = Path.build_filename(
                        icon_dir, 
                        theme, 
                        size_dir, 
                        "apps", 
                        icon_name + ext
                    );
                    if (FileUtils.test(icon_path, FileTest.EXISTS)) {
                        return icon_path;
                    }
                }
            }
            
            // Try without theme subdirectory
            foreach (string ext in extensions) {
                string icon_path = Path.build_filename(icon_dir, icon_name + ext);
                if (FileUtils.test(icon_path, FileTest.EXISTS)) {
                    return icon_path;
                }
            }
        }
        
        return null;
    }  */
    
}