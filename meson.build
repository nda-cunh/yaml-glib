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

executable(
  'yaml-glib',
  sources,
  dependencies : dependencies,
  c_args: '-w',
  install : true,
)
