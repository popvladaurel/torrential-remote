public class Main.Window : Gtk.ApplicationWindow {
    public Settings settings;
    public Main.HeaderBar headerBar;
    public Gtk.ScrolledWindow scroll;
    public Server.Model selectedServer;
    public bool dark_theme { get; set; }
    public Client.View? torrents;

    private Granite.Widgets.SourceList serversList;
    private Gee.ArrayList<Server.Model> savedServers;
    private Gee.ArrayList<Server.Item> serverItems = new Gee.ArrayList<Server.Item> ();
    private Server.Controller serverController;

    construct {
        settings = new Settings ("com.github.popvladaurel.torrential-remote");
        dark_theme = settings.get_boolean ("dark-theme");
        scroll = new Gtk.ScrolledWindow (null, null);
        headerBar = new Main.HeaderBar (this);
        delete_event.connect (event => before_destroy ());
    }

    public Window (Gee.ArrayList<Server.Model> servers) {
        savedServers = servers;
        serverController = new Server.Controller ();
        set_default_size (
            settings.get_int ("window-width"),
            settings.get_int ("window-height")
        );
        move (settings.get_int ("window-pos-x"), settings.get_int ("window-pos-y"));

        Gtk.Paned paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        Gtk.Box sidebar = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        serversList = new Granite.Widgets.SourceList ();
        serversList.vexpand = true;
        serversList.set_margin_start (5);

        Server.Model? defaultServer = null;
        foreach (Server.Model server in savedServers) {
            Server.Item item = new Server.Item (server);
            item.make_default_requested.connect (set_default_server);
            serverItems.add (item);
            serversList.root.add (item);
            if (server.is_default)
                defaultServer = server;
        }
        sidebar.pack_start (serversList, true, true, 0);

        Gtk.ActionBar actions = new Gtk.ActionBar ();
        Gtk.Button add_button = new Gtk.Button.from_icon_name ("list-add-symbolic", Gtk.IconSize.BUTTON);
        add_button.tooltip_text = "Add a server";
        add_button.clicked.connect (() => {
            new Server.Dialog (savedServers);
        });
        actions.pack_start (add_button);

        Gtk.Button remove_button = new Gtk.Button.from_icon_name ("list-remove-symbolic", Gtk.IconSize.BUTTON);
        remove_button.tooltip_text = "Remove selected server";
        remove_button.clicked.connect (() => {
            Server.Item? selected = serversList.selected as Server.Item;
            if (selected == null)
                return;
            serverController.delete (selected.server);
            savedServers.remove (selected.server);
            serverItems.remove (selected);
            serversList.root.remove (selected);
            if (savedServers.size > 0 && selected.server.is_default) {
                savedServers[0].is_default = true;
                serverController.set_default (savedServers[0]);
                serverItems[0].update_label ();
            }
            if (savedServers.size > 0)
                connect_to_server (savedServers[0]);
        });
        actions.pack_start (remove_button);
        sidebar.pack_end (actions, false, false, 0);

        paned.position = 190;
        paned.wide_handle = true;
        paned.pack1 (sidebar, false, false);
        paned.pack2 (scroll, true, false);
        set_titlebar (headerBar);
        add (paned);

        serversList.item_selected.connect ((selected_item) => {
            Server.Item? item = selected_item as Server.Item;
            if (item != null)
                connect_to_server (item.server);
        });

        if (defaultServer == null && savedServers.size > 0) {
            defaultServer = savedServers[0];
            serverController.set_default (defaultServer);
            defaultServer.is_default = true;
            foreach (Server.Item item in serverItems)
                item.update_label ();
        }
        if (defaultServer != null)
            connect_to_server (defaultServer);
        else {
            Gtk.Label empty = new Gtk.Label ("Add a server to get started");
            empty.get_style_context ().add_class ("dim-label");
            empty.expand = true;
            scroll.add (empty);
        }

        show_all ();
        Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = dark_theme;
    }

    private void connect_to_server (Server.Model server) {
        selectedServer = server;
        if (torrents != null)
            scroll.remove (torrents);
        torrents = new Client.View (server);
        scroll.add (torrents);
        torrents.show_all ();
    }

    private void set_default_server (Server.Model server) {
        if (!serverController.set_default (server))
            return;
        foreach (Server.Model saved in savedServers)
            saved.is_default = saved.equals (server);
        foreach (Server.Item item in serverItems)
            item.update_label ();
    }

    public bool before_destroy () {
        int width, height, x, y;
        get_size (out width, out height);
        get_position (out x, out y);
        settings.set_int ("window-pos-x", x);
        settings.set_int ("window-pos-y", y);
        settings.set_int ("window-width", width);
        settings.set_int ("window-height", height);
        settings.set_boolean ("dark-theme", dark_theme);
        return false;
    }
}
