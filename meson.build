project(
  'com.github.popvladaurel.torrential-remote',
  'vala',
  'c',
  version: '0.2.0',
  meson_version: '>= 0.59.0',
  default_options: ['warning_level=2', 'werror=false']
)

subdir('data')
subdir('src')

meson.add_install_script('meson/post_install.py')
