public class Server.Item : Granite.Widgets.SourceList.Item {
    Gtk.Menu menu = new Gtk.Menu ();
    public Server.Model server;
    public signal void make_default_requested (Server.Model server);

    public Item (Server.Model server) {
        this.server = server;
        icon = new ThemedIcon ("network-server");
        update_label ();
        build_menu ();
    }

    public void update_label () {
        string kind = server.protocol == "auto" ? "Auto" :
            (server.protocol == "deluge" ? "Deluge" : "Transmission");
        name = server.is_default
            ? "%s · %s · Default".printf (server.name, kind)
            : "%s · %s".printf (server.name, kind);
    }

    public override Gtk.Menu? get_context_menu () {
        return menu;
    }

    private void build_menu () {
        Gtk.MenuItem default_item = new Gtk.MenuItem.with_label ("Set as default server");
        default_item.sensitive = !server.is_default;
        default_item.activate.connect (() => make_default_requested (server));
        menu.add (default_item);

        Gtk.MenuItem edit = new Gtk.MenuItem.with_label ("Edit server settings");
        edit.activate.connect (() => {
            GLib.Application.get_default ().send_notification (null,
                new Notification ("Edit server settings from the server configuration dialog."));
        });
        menu.add (edit);

        Gtk.MenuItem remove = new Gtk.MenuItem.with_label ("Delete");
        remove.activate.connect (() => {
            Server.Controller controller = new Server.Controller ();
            controller.delete (server);
        });
        menu.add (remove);
        menu.show_all ();
    }
}
