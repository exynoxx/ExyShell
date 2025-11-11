wayland_client_dep = dependency('wayland-client', required: true)
wayland_egl_dep    = dependency('wayland-egl', required: true)
egl_dep            = dependency('egl', required: true)
glesv2_dep         = dependency('glesv2', required: true)

headers = include_directories('include')
sources = [
  'src/main.c',
  'src/egl.c',
  'src/registry.c',
  'src/wayland_features/compositor.c',
  'src/wayland_features/layershell.c',
  'src/wayland_features/seat.c',
  'src/wayland_features/toplevel.c',
  'src/wayland_protocols/wlr-layer-shell-unstable-v1-protocol.c',
  'src/wayland_protocols/xdg-shell-client-protocol.c',
  'src/wayland_protocols/wlr-foreign-toplevel-management-unstable-v1-protocol.c'
]

# --- Build shared library ---
liblayershell = static_library(
  'layershell',
  sources,
  dependencies: [wayland_client_dep, wayland_egl_dep, egl_dep, glesv2_dep],
  include_directories: headers
)

liblayershell_dep = declare_dependency(
    include_directories: headers,
    link_with: liblayershell,
    dependencies: [wayland_client_dep, wayland_egl_dep, egl_dep, glesv2_dep]
)