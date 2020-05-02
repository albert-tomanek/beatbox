# project name and programming language
project('com.github.albert-tomanek.beatbox', 'vala', 'c', version: '0.1.0')

message ('project name and programming language')

# Adds project arguments
message ('Adds project arguments')

add_project_arguments([
        '-DGETTEXT_PACKAGE=\"@0@\"'.format(meson.project_name())
    ],
    language: 'c',
)

# Include the translations module
message('Include the translations module')

i18n = import('i18n')

# Set our translation domain
message ('Set our translation domain')

add_global_arguments('-DGETTEXT_PACKAGE=\"@0@\"'.format (meson.project_name()), language:'c')

# Adding deps
message ('Listing dependencies')

add_project_arguments(['-I ', meson.current_source_dir() / 'src/gst/'], language: 'c')
add_project_arguments(['--vapidir', meson.current_source_dir() / 'src/gst/', '--pkg', 'mygstaudiofilter'], language: 'vala')

dependencies = [
    dependency('gio-unix-2.0', version: '>=2.20'),
    dependency('granite'),
	dependency('gstreamer-1.0'),
	dependency('gstreamer-audio-1.0'),
	dependency('gstreamer-app-1.0'),
	dependency('gst-editing-services-1.0'),

#	dependency('mygstaudiofilter'),	# This is our custom vapi in src/gst/
]

# Adds subfolders specific build system
message ('Adds subfolders specific build system')

icon_sizes = ['128', '256']

foreach i : icon_sizes
    install_data(
        join_paths('data/icons', i, meson.project_name() + '.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i, 'apps')
    )
    install_data(
        join_paths('data/icons', i, meson.project_name() + '.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i + '@2', 'apps')
    )
endforeach

config_data = configuration_data()
config_data.set('EXEC_NAME', meson.project_name())

# Src build
message ('Src build')

conf_data = configuration_data()
conf_data.set_quoted('PROJECT_NAME', meson.project_name())
conf_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf_data.set_quoted('VERSION', meson.project_version())
conf_data.set_quoted('PREFIX', get_option('prefix'))

message ('Configuring desktop entry: ' + meson.project_name() + '.desktop')

desktop_in_file = configure_file(
    input: join_paths('data', meson.project_name() + '.desktop.in.in'),
    output: '@BASENAME@',
    configuration: config_data
)

desktop_file = i18n.merge_file(
    input: desktop_in_file,
    output: meson.project_name() + '.desktop',
    po_dir: join_paths(meson.source_root(), 'po'),
    type: 'desktop',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'applications')
)

appstream_file = i18n.merge_file(
    input: join_paths (meson.source_root(), 'data', meson.project_name() + '.appdata.xml.in'),
    output: '@BASENAME@',
    po_dir: join_paths(meson.source_root(), 'po'),
    install: true,
    install_dir: join_paths(get_option('datadir'), 'metainfo')
)

message ('Compile GResources')

gnome = import('gnome')

resources = gnome.compile_resources(
   'beatbox_res', 'data/resources.xml',
   source_dir: 'data/',
	export: true,
)

message ('Adds files to build')

code_files = files(
    'src/main.vala',
	'src/tile.vala',
	'src/tilehost.vala',
	'src/tiles/dummytile.vala',
	'src/tiles/looptile.vala',
	'src/gst/meanamplitude.vala',
)

message ('Defines executable')

executable(
    meson.project_name(),
	resources,
    sources: code_files,
    dependencies: dependencies,
    install: true,
	include_directories: include_directories('src/gst/'),
)
