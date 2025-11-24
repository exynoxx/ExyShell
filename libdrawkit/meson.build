project('drawkit', 'c',
  version : '1.0'
)


sources = [
  'backend.c',
  'nanosvg.c',
  'structures.c',
  'texture.c'
]

drawkit = static_library(
  'drawkit',
  sources,
  include_directories: include_directories('.'),
  pic: true
)

drawkit_dep = declare_dependency(
  link_with: drawkit,
  include_directories: include_directories('.')
)
