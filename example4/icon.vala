public class IconUtils {
    // Load icon as texture
    public static Gdk.Texture? load_icon(string icon_name, int size = 32) {
        // Method 1: Load from icon theme
        var icon_theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default());
        var icon_paintable = icon_theme.lookup_icon(
            icon_name,
            null,  // fallbacks
            size,
            1,     // scale
            Gtk.TextDirection.NONE,
            Gtk.IconLookupFlags.FORCE_REGULAR
        );
        
        if (icon_paintable != null) {
            var file = icon_paintable.get_file();
            if (file != null) {
                try {
                    return Gdk.Texture.from_file(file);
                } catch (Error e) {
                    warning("Failed to load icon: %s", e.message);
                }
            }
        }
        
        return null;
    }

    // Method 2: Load from file path (PNG/SVG)
    public static Gdk.Texture? load_icon_from_path(string path) {
        try {
            var file = File.new_for_path(path);
            return Gdk.Texture.from_file(file);
        } catch (Error e) {
            warning("Failed to load icon from path: %s", e.message);
            return null;
        }
    }

    // Method 3: Load from resource
    public static Gdk.Texture? load_icon_from_resource(string resource_path) {
        try {
            return Gdk.Texture.from_resource(resource_path);
        } catch (Error e) {
            warning("Failed to load icon from resource: %s", e.message);
            return null;
        }
    }
}