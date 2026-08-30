# Known bugs

Confirmed, reproducible, not yet fixed. Remove the entry when it's fixed.

## lumen-settings

### Per-app volume label always reads 0%
`lumen-settings/src/pages/sound_page.vala:340`

`make_app_row()` only updates `aw.label` from inside the slider's own
`value_changed` handler, which early-returns while `syncing` is true.
`sync_app_rows()` sets `aw.scale` under exactly that guard, so the label is
never refreshed from `s.volume_pct`. Every application row shows `0%` until
the user drags that specific slider. `out_label`/`in_label` are set explicitly
in `sync_ui()` and are correct — only the per-app rows are affected.

Fix: set `aw.label.label` alongside `aw.scale.set_value()` in `sync_app_rows()`.

### "Allow volume above 100%" does not persist
`lumen-settings/src/pages/sound_page.vala:123`

The toggle really does re-range the slider, but `allow_over` is a plain field
hardcoded `false` at construction and never read from or written to any store.
It resets on every Settings launch, and if the sink is above 100% the next
poll re-clamps the slider back down.

Fix: back it with a key in the sound config, or drop the row.

### Wallpaper page changes the lock screen, not the desktop
`lumen-settings/src/pages/wallpaper_page.vala:25`

The "Image" row writes `wallpaper.ini [wallpaper] image`. The only consumer in
the tree is `lumen-lockscreen/src/widgets/blurred_wallpaper.vala:46` (the
backdrop). The actual desktop background is drawn by `wf-background`, which
reads `~/.config/wf-shell.ini [background] image` — a file lumen-settings never
writes. Setting a wallpaper therefore has no visible effect on the desktop.

Fix: mirror the path into `wf-shell.ini`, or own the wallpaper in
lumen-desktop and read `wallpaper.ini` there.

### "Blank screen after" is a no-op without the idle plugin
`lumen-settings/src/pages/power_page.vala:53`

Writes `wayfire.ini [idle] dpms_timeout`, a real Wayfire option, but Wayfire
only honours it when `idle` is listed in `[core] plugins`. The page never adds
it. The Drawer and Panel pages manage `[core] plugins` via
`Wayfire.PluginList.set_enabled()`; this one does not.

Fix: call `PluginList.set_enabled("idle", true)` when the value is non-zero.
