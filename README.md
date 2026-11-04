# Torrential Remote

Torrential Remote is a desktop client for connecting to one or more remote Transmission servers. It supports adding torrents from magnet links or `.torrent` files, monitoring transfer progress, pausing and resuming transfers, and removing torrents.

## Build dependencies

The project uses the maintained GTK 3 API (3.24 or newer), Granite, Gee, libsoup 2.4, and JSON-GLib. The Meson dependency declarations specify minimum compatible API versions; package managers install the current compatible packages for the target distribution. GTK 3 and libsoup 2 remain the application’s current toolkit and RPC transport, respectively—this is not a GTK 4 / libsoup 3 port.

On Debian/Ubuntu-derived systems, install the development packages `valac`, `meson`, `ninja-build`, `libgtk-3-dev`, `libgranite-dev`, `libgee-0.8-dev`, `libsoup2.4-dev`, and `libjson-glib-dev`.

## Build and install

```sh
git clone https://github.com/popvladaurel/torrential-remote.git
cd torrential-remote
meson setup build --prefix=/usr
meson compile -C build
sudo meson install -C build
```

For a local, unprivileged install, use a prefix such as `~/.local` instead of `/usr`.

## Transmission server

Configure the server’s RPC endpoint (usually port 9091 and `/transmission/rpc`) and credentials in the application. Ensure that remote RPC access is enabled and reachable on the network. Prefer HTTPS or a trusted private network when credentials are used.

## UI direction

The interface keeps elementary-style header-bar and Granite patterns, follows the desktop’s system theme, and uses GTK 3.24. A full GTK 4 / Granite 7 migration is separate work because the current UI and APIs are GTK 3 based.
