// Load icon as texture
public Gdk.Texture? load_icon(string icon_name, int size = 32) {
    // Method 1: Load from icon theme
    var icon_theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default());
    var icon_paintable = icon_theme.lookup_icon(
        icon_name,
        null,  // fallbacks
        size,
        1,     // scale
        Gtk.TextDirection.NONE,
        Gtk.IconLookupFlags.NONE
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
public Gdk.Texture? load_icon_from_path(string path) {
    try {
        var file = File.new_for_path(path);
        return Gdk.Texture.from_file(file);
    } catch (Error e) {
        warning("Failed to load icon from path: %s", e.message);
        return null;
    }
}

// Method 3: Load from resource
public Gdk.Texture? load_icon_from_resource(string resource_path) {
    try {
        return Gdk.Texture.from_resource(resource_path);
    } catch (Error e) {
        warning("Failed to load icon from resource: %s", e.message);
        return null;
    }
}

// Usage in snapshot
public override void snapshot(Gtk.Snapshot snapshot) {
    // Load icon
    var texture = load_icon("firefox", 32);
    // or: var texture = load_icon_from_path("/usr/share/icons/hicolor/32x32/apps/firefox.png");
    
    if (texture != null) {
        var icon_rect = Graphene.Rect() {
            origin = { 10, 10 },
            size = { 32, 32 }
        };
        snapshot.append_texture(texture, icon_rect);
    }
}