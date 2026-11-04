app_deps = [
  dependency('gtk+-3.0', version: '>= 3.24'),
  dependency('granite', version: '>= 5.2'),
  dependency('gee-0.8', version: '>= 0.20'),
  dependency('libsoup-2.4', version: '>= 2.74'),
  dependency('json-glib-1.0', version: '>= 1.6'),
]

executable(
  meson.project_name(),
  'Main.vala',
  'Application.vala',
  'Main/Window.vala',
  'Main/HeaderBar.vala',
  'Torrent/Row.vala',
  'Torrent/Model.vala',
  'Torrent/Statuses.vala',
  'Client/Model.vala',
  'Client/View.vala',
  'Server/Item.vala',
  'Server/Model.vala',
  'Server/Dialog.vala',
  'Server/Controller.vala',
  dependencies: app_deps,
  install: true
)
