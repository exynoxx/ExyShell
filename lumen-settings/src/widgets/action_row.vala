namespace LumenSettings {

    // Adw.ActionRow plus a single-slot `set_suffix()`, which the
    // Switch/Spin/Entry/Color/File/Binding rows all build on.
    public class ActionRow : Adw.ActionRow {
        Gtk.Widget? current_suffix = null;

        public ActionRow(string title, string subtitle = "") {
            // Plain labels, not markup: avoids an `&`/`<` in a title being
            // misread as Pango markup.
            use_markup = false;
            this.title = title;
            this.subtitle = subtitle ?? "";
        }

        // Replace whatever sits in the suffix area with `w`. Mirrors the old
        // single-slot behaviour the subclasses rely on.
        public void set_suffix(Gtk.Widget w) {
            if (current_suffix != null) {
                remove(current_suffix);
            }
            w.valign = Gtk.Align.CENTER;
            add_suffix(w);
            current_suffix = w;
        }
    }
}
