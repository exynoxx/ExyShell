using Gtk;

// The canonical Apple Wi-Fi glyph: a center dot with three nested arcs fanning
// upward. Signal strength dims the outer arcs rather than dropping bars, the
// way iOS/macOS render it. Drawn purely with GSK paths (append_stroke /
// append_fill) so the ngl/Vulkan renderer rasterizes it on the GPU — no Cairo
// software fallback.
public class WifiArc {

    // Render the glyph with its dot centered at (cx, cy). Active arcs are
    // full-strength; the rest fade to 25% so a weak signal reads as a dim outer
    // ring. The 90° fans are exact circular arcs (svg_arc_to), the dot a filled
    // circle.
    public static void draw (Gtk.Snapshot s, float cx, float cy,
                             int signal_pct, Gdk.RGBA fg) {
        int active = signal_pct >= 67 ? 3 : signal_pct >= 34 ? 2 : signal_pct >= 1 ? 1 : 0;

        const float K = 0.70710677f;   // cos/sin 45°
        float[] radii = { 4.0f, 8.0f, 12.0f };

        var stroke = new Gsk.Stroke (2.0f);
        stroke.set_line_cap (Gsk.LineCap.ROUND);

        for (int i = 0; i < 3; i++) {
            float sx = cx - K * radii[i];
            float ex = cx + K * radii[i];
            float ay = cy - K * radii[i];   // both endpoints sit above center

            var b = new Gsk.PathBuilder ();
            b.move_to (sx, ay);
            // Minor arc bulging over the top (positive sweep, y-down).
            b.svg_arc_to (radii[i], radii[i], 0f, false, true, ex, ay);

            var col = fg;
            col.alpha = (i < active) ? fg.alpha : fg.alpha * 0.25f;
            s.append_stroke (b.to_path (), stroke, col);
        }

        var dot = new Gsk.PathBuilder ();
        var c = Graphene.Point ();
        c.init (cx, cy);
        dot.add_circle (c, 1.6f);
        s.append_fill (dot.to_path (), Gsk.FillRule.WINDING, fg);
    }
}
