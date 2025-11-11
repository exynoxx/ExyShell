glesv2_dep = dependency('glesv2', required: true)

c_sources = [
    'src/backend.c',
    'src/hover.c',
    'src/layout.c',
    'src/nanosvg.c',
    'src/texture.c'
]
headers = include_directories('include')

libdrawkit = static_library('drawkit', c_sources,
    include_directories: headers,
    install: true,
    dependencies: [glesv2_dep]
)

libdrawkit_dep = declare_dependency(
    include_directories: headers,
    link_with: libdrawkit,
    dependencies: [glesv2_dep]
)