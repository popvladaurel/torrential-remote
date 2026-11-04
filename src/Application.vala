public class Application : Gtk.Application {
    private Main.Window? window = null;
    private Server.Controller serverController;
    public Gee.ArrayList<Server.Model> serversList;

    public Application () {
        Object (
            application_id: "com.github.popvladaurel.torrential-remote",
            flags: ApplicationFlags.HANDLES_OPEN
        );
    }

    construct {
        serverController = new Server.Controller ();
        serversList = serverController.all ();
        DesktopAppInfo? appinfo = new DesktopAppInfo (get_application_id () + ".desktop");
        if (appinfo != null) {
            try {
                appinfo.set_as_last_used_for_type ("x-scheme-handler/magnet");
                appinfo.set_as_last_used_for_type ("application/x-bittorrent");
            } catch (Error error) {
                warning ("Unable to register torrent file handlers: %s", error.message);
            }
        }
    }

    private Server.Model? default_server () {
        foreach (Server.Model server in serversList) {
            if (server.is_default)
                return server;
        }
        return serversList.size > 0 ? serversList[0] : null;
    }

    protected override void activate () {
        serversList = serverController.all ();
        Server.Model? selected = default_server ();
        if (selected == null) {
            new Server.Dialog (serversList);
            serversList = serverController.all ();
        }
        window = new Main.Window (serversList);
        add_window (window);
        window.present ();
    }

    public override void open (File[] files, string hint) {
        serversList = serverController.all ();
        Server.Model? selected = default_server ();
        if (selected == null) {
            new Server.Dialog (serversList);
            serversList = serverController.all ();
            selected = default_server ();
        }
        if (selected != null) {
            foreach (File file in files) {
                try {
                    uint8[] contents;
                    string etag_out;
                    file.load_contents (null, out contents, out etag_out);
                    Client.Model client = new Client.Model (selected);
                    if (!client.add_from_file (contents))
                        warning ("Could not add torrent: %s", client.last_error);
                } catch (Error error) {
                    warning ("Could not read torrent file: %s", error.message);
                }
            }
        }
        activate ();
    }
}
