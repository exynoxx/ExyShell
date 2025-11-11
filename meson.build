project('exy-panel', 'vala', 'c')

# Vala compiler options
vala_pkg_deps = [
  dependency('glesv2'),
  dependency('wayland-client'),
  dependency('glib-2.0'),
  dependency('gee-0.8'),
  dependency('egl')
]

subdir('libdrawkit/')
subdir('liblayershell/')

# Expose dependencies from subprojects
drawkit_dep = dependency('libdrawkit', fallback: ['libdrawkit', 'libdrawkit_dep'])
layershell_dep = dependency('liblayershell', fallback: ['liblayershell', 'liblayershell_dep'])

# Vala sources
vala_sources = files('src/*.vala')

# Build the executable
executable('exy-panel', vala_sources,
  dependencies: vala_pkg_deps + [drawkit_dep, layershell_dep],
  install: true
)
