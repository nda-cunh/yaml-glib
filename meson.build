project(
  'yaml-glib',
  ['vala', 'c'],
  meson_version : '>= 1.0.0',
  version : '0.1',
  default_options : [
    'warning_level=0',
    'optimization=3',
  ],
)

vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

add_global_arguments('--pkg=tree-sitter', language: 'vala')

dependencies = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('tree-sitter', static: true),
  dependency('tree-sitter-yaml', static: true),
]

subdir('src')

lib_yaml_glib = static_library(
  'yaml-glib',
  sources,
  dependencies : dependencies,
  vala_vapi : 'yaml-glib.vapi',
  vala_header : 'yaml-glib.h',
  include_directories : include_directories('.'),
  c_args: '-w',
  install : true,
)

dep_yaml_glib = declare_dependency(
  link_with : lib_yaml_glib,
  include_directories : include_directories('.'),
  dependencies : dependencies,
)

meson.override_dependency('yaml-glib', dep_yaml_glib)

executable(
  'yaml-glib',
  'src/main.vala',
  dependencies : dep_yaml_glib,
  install : true,
)
