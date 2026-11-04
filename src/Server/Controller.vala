class Server.Controller : Object {
    File serversFile;
    File configFolder;
    string configLocation;

    construct {
        configLocation = GLib.Environment.get_user_config_dir () + "/com.github.popvladaurel.torrential-remote";
        configFolder = File.new_for_path (configLocation);
        if (!configFolder.query_exists ()) {
            try {
                configFolder.make_directory_with_parents ();
            } catch (Error error) {
                warning ("Could not create the server configuration directory: %s", error.message);
            }
        }
        serversFile = configFolder.get_child ("servers.json");
        if (!serversFile.query_exists ()) {
            try {
                serversFile.create (FileCreateFlags.NONE).close ();
            } catch (Error error) {
                warning ("Could not create server configuration file: %s", error.message);
            }
        }
    }

    public Gee.ArrayList<Server.Model> all () {
        return read_servers ();
    }

    public Server.Model? default_server () {
        foreach (Server.Model server in read_servers ()) {
            if (server.is_default)
                return server;
        }
        return null;
    }

    public bool save (Server.Model server) {
        Gee.ArrayList<Server.Model> servers = read_servers ();
        bool first_server = servers.size == 0;
        bool replaced = false;
        foreach (Server.Model existing in servers) {
            if (existing.equals (server)) {
                existing.name = server.name;
                existing.host = server.host;
                existing.port = server.port;
                existing.path = server.path;
                existing.user = server.user;
                existing.pass = server.pass;
                existing.protocol = server.protocol;
                existing.auto = server.auto;
                if (server.is_default) {
                    foreach (Server.Model item in servers)
                        item.is_default = item == existing;
                }
                replaced = true;
                break;
            }
        }
        if (!replaced)
            servers.add (server);

        if (first_server)
            server.is_default = true;
        if (server.is_default) {
            foreach (Server.Model item in servers)
                item.is_default = item.equals (server);
        }
        return write_servers (servers);
    }

    public bool set_default (Server.Model server) {
        Gee.ArrayList<Server.Model> servers = read_servers ();
        bool found = false;
        foreach (Server.Model item in servers) {
            item.is_default = item.equals (server);
            found = found || item.is_default;
        }
        if (!found)
            return false;
        bool saved = write_servers (servers);
        if (saved)
            server.is_default = true;
        return saved;
    }

    public bool delete (Server.Model server) {
        Gee.ArrayList<Server.Model> servers = read_servers ();
        bool removed_default = server.is_default;
        servers.remove (server);
        if (removed_default && servers.size > 0)
            servers[0].is_default = true;
        return write_servers (servers);
    }

    private Gee.ArrayList<Server.Model> read_servers () {
        Gee.ArrayList<Server.Model> servers = new Gee.ArrayList<Server.Model> ((Gee.EqualDataFunc) Server.Model.equals);
        try {
            Json.Parser parser = new Json.Parser ();
            parser.load_from_stream (serversFile.read ());
            Json.Node? root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.ARRAY)
                return servers;
            foreach (Json.Node node in root.get_array ().get_elements ()) {
                if (node.get_node_type () != Json.NodeType.OBJECT)
                    continue;
                Json.Object data = node.get_object ();
                Server.Model server = new Server.Model ();
                if (data.has_member ("name")) server.name = data.get_string_member ("name");
                if (data.has_member ("host")) server.host = data.get_string_member ("host");
                if (data.has_member ("port")) server.port = data.get_string_member ("port");
                if (data.has_member ("path")) server.path = data.get_string_member ("path");
                if (data.has_member ("user")) server.user = data.get_string_member ("user");
                if (data.has_member ("pass")) server.pass = data.get_string_member ("pass");
                if (data.has_member ("url")) server.url = data.get_string_member ("url");
                if (data.has_member ("sessionId")) server.sessionId = data.get_string_member ("sessionId");
                if (data.has_member ("protocol")) server.protocol = data.get_string_member ("protocol");
                if (data.has_member ("is_default")) server.is_default = data.get_boolean_member ("is_default");
                servers.add (server);
            }
        } catch (Error error) {
            warning ("Unable to read '%s': %s", serversFile.get_basename (), error.message);
        }
        return servers;
    }

    private bool write_servers (Gee.ArrayList<Server.Model> servers) {
        Json.Builder builder = new Json.Builder ();
        builder.begin_array ();
        foreach (Server.Model server in servers)
            builder.add_value (Json.gobject_serialize (server));
        builder.end_array ();
        Json.Generator generator = new Json.Generator ();
        generator.set_root (builder.get_root ());
        generator.pretty = true;
        try {
            generator.to_file (serversFile.get_path ());
            return true;
        } catch (Error error) {
            warning ("Unable to save server configuration: %s", error.message);
            return false;
        }
    }
}
