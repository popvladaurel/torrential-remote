public class Client.Model : Object {
    public string sessionId { get; set; default = ""; }
    public string url { get; set; }
    public string username { get; set; default = ""; }
    public string password { get; set; default = ""; }
    public string last_error { get; private set; default = ""; }
    public string protocol { get; private set; default = "auto"; }

    private Server.Model server;
    private string deluge_cookie = "";
    private int rpc_id = 1;
    private Gee.HashMap<int,string> deluge_hashes = new Gee.HashMap<int,string> ();

    private static string[] torrent_fields = {
        "id", "name", "eta", "status", "recheckProgress", "percentDone",
        "haveValid", "uploadedEver", "peersConnected", "peersSendingToUs",
        "peersGettingFromUs", "rateDownload", "rateUpload", "sizeWhenDone",
        "files", "error", "errorString"
    };

    public Model (Server.Model server) {
        this.server = server;
        protocol = server.protocol;
        url = server.rpc_url ();
        username = server.user;
        password = server.pass;
        sessionId = server.sessionId;
    }

    private Json.Object? post_json (Soup.Session session, string target, Json.Object body, bool use_cookie = false) {
        Json.Node root = new Json.Node (Json.NodeType.OBJECT);
        root.set_object (body);
        Json.Generator generator = new Json.Generator ();
        generator.set_root (root);
        string payload = generator.to_data (null);
        Soup.Message message = new Soup.Message ("POST", target);
        if (message == null) {
            last_error = "The server URL is invalid.";
            return null;
        }
        message.set_request ("application/json", Soup.MemoryUse.COPY, payload.data);
        if (use_cookie && deluge_cookie != "")
            message.request_headers.replace ("Cookie", deluge_cookie);
        uint status = session.send_message (message);
        if (status < 200 || status >= 300) {
            last_error = "Server returned HTTP %u.".printf (status);
            return null;
        }
        try {
            Json.Parser parser = new Json.Parser ();
            parser.load_from_data ((string) message.response_body.flatten ().data, -1);
            Json.Node? response_root = parser.get_root ();
            if (response_root == null || response_root.get_node_type () != Json.NodeType.OBJECT) {
                last_error = "Server returned an invalid JSON-RPC response.";
                return null;
            }
            return response_root.get_object ();
        } catch (Error error) {
            last_error = "Could not parse the server response: %s".printf (error.message);
            return null;
        }
    }

    private Json.Object rpc_body (string method, Json.Array arguments, int id) {
        Json.Object body = new Json.Object ();
        body.set_int_member ("id", id);
        body.set_string_member ("method", method);
        body.set_array_member ("params", arguments);
        return body;
    }

    private bool detect_protocol () {
        if (protocol != "auto")
            return true;
        last_error = "";
        Soup.Session session = new Soup.Session ();
        Json.Object body = new Json.Object ();
        body.set_string_member ("method", "session-get");
        body.set_object_member ("arguments", new Json.Object ());
        Json.Node root = new Json.Node (Json.NodeType.OBJECT);
        root.set_object (body);
        Json.Generator generator = new Json.Generator ();
        generator.set_root (root);
        string payload = generator.to_data (null);
        string transmission_url = server.rpc_url_for ("transmission");
        Soup.Message message = new Soup.Message ("POST", transmission_url);
        message.set_request ("application/json", Soup.MemoryUse.COPY, payload.data);
        uint status = session.send_message (message);
        if (status == Soup.Status.CONFLICT || (status >= 200 && status < 300)) {
            protocol = "transmission";
            url = transmission_url;
            server.protocol = protocol;
            server.url = url;
            if (status == Soup.Status.CONFLICT)
                sessionId = message.response_headers.get_one ("X-Transmission-Session-Id") ?? "";
            return true;
        }

        string deluge_port = server.port;
        if (deluge_port == "" || deluge_port == "9091")
            deluge_port = "8112";
        string deluge_url = server.rpc_url_for ("deluge", deluge_port);
        Soup.Session deluge_session = new Soup.Session ();
        Json.Array login_params = new Json.Array ();
        login_params.add_string_element (password);
        Json.Object? login = post_json (deluge_session, deluge_url, rpc_body ("auth.login", login_params, rpc_id++));
        if (login != null && login.has_member ("result") && !login.get_null_member ("result")) {
            protocol = "deluge";
            url = deluge_url;
            server.protocol = protocol;
            server.port = deluge_port;
            server.path = "/json";
            server.url = url;
            return true;
        }
        last_error = "Could not identify a Transmission RPC or Deluge Web server at this address. Check the host, port, and credentials.";
        return false;
    }

    private Json.Object? transmission_request (string method, Json.Object arguments) {
        Soup.Session session = new Soup.Session ();
        session.authenticate.connect ((message, auth, retrying) => {
            if (username != "" || password != "")
                auth.authenticate (username, password);
        });
        for (int attempt = 0; attempt < 2; attempt++) {
            Json.Object body = new Json.Object ();
            body.set_string_member ("method", method);
            body.set_object_member ("arguments", arguments);
            Json.Node root = new Json.Node (Json.NodeType.OBJECT);
            root.set_object (body);
            Json.Generator generator = new Json.Generator ();
            generator.set_root (root);
            string payload = generator.to_data (null);
            Soup.Message message = new Soup.Message ("POST", url);
            message.set_request ("application/json", Soup.MemoryUse.COPY, payload.data);
            if (sessionId != "")
                message.request_headers.replace ("X-Transmission-Session-Id", sessionId);
            uint status = session.send_message (message);
            if (status == Soup.Status.CONFLICT) {
                string? token = message.response_headers.get_one ("X-Transmission-Session-Id");
                if (token == null || attempt != 0) {
                    last_error = "Transmission rejected the RPC session.";
                    return null;
                }
                sessionId = token;
                server.sessionId = token;
                continue;
            }
            if (status < 200 || status >= 300) {
                last_error = "Transmission returned HTTP %u.".printf (status);
                return null;
            }
            try {
                Json.Parser parser = new Json.Parser ();
                parser.load_from_data ((string) message.response_body.flatten ().data, -1);
                Json.Node? response_root = parser.get_root ();
                if (response_root == null || response_root.get_node_type () != Json.NodeType.OBJECT) {
                    last_error = "Transmission returned an invalid RPC response.";
                    return null;
                }
                Json.Object response = response_root.get_object ();
                if (response.get_string_member ("result") != "success") {
                    last_error = "Transmission RPC failed: %s".printf (response.get_string_member ("result"));
                    return null;
                }
                return response;
            } catch (Error error) {
                last_error = "Could not read the Transmission response: %s".printf (error.message);
                return null;
            }
        }
        last_error = "Could not establish an RPC session with Transmission.";
        return null;
    }

    private Json.Object? deluge_request (string method, Json.Array args) {
        Soup.Session session = new Soup.Session ();
        if (deluge_cookie == "") {
            Json.Array login_params = new Json.Array ();
            login_params.add_string_element (password);
            Json.Object? login = post_json (session, url, rpc_body ("auth.login", login_params, rpc_id++));
            if (login == null || !login.has_member ("result") || login.get_null_member ("result") ||
                !login.get_boolean_member ("result")) {
                if (last_error == "")
                    last_error = "Deluge login failed. Check the Web UI password.";
                return null;
            }
        }
        Json.Object? response = post_json (session, url, rpc_body (method, args, rpc_id++), true);
        if (response == null)
            return null;
        if (response.has_member ("error") && !response.get_null_member ("error")) {
            last_error = "Deluge RPC failed while calling %s.".printf (method);
            return null;
        }
        if (!response.has_member ("result")) {
            last_error = "Deluge returned a response without a result.";
            return null;
        }
        return response;
    }

    private Json.Array get_deluge_torrents () {
        Json.Array fields = new Json.Array ();
        string[] wanted = { "name", "state", "progress", "total_size", "total_done", "total_uploaded", "download_payload_rate", "upload_payload_rate", "num_peers", "eta", "files", "message" };
        foreach (string field in wanted)
            fields.add_string_element (field);
        Json.Array args = new Json.Array ();
        args.add_object_element (new Json.Object ());
        args.add_array_element (fields);
        Json.Object? response = deluge_request ("core.get_torrents_status", args);
        Json.Array normalized = new Json.Array ();
        deluge_hashes.clear ();
        if (response == null || response.get_null_member ("result"))
            return normalized;

        Json.Object torrent_map = response.get_object_member ("result");
        foreach (string hash in torrent_map.get_members ()) {
            Json.Object info = torrent_map.get_object_member (hash);
            int id = (int) (hash.hash () & 0x7fffffff);
            deluge_hashes.set (id, hash);
            Json.Object item = new Json.Object ();
            item.set_int_member ("id", id);
            item.set_string_member ("name", info.has_member ("name") ? info.get_string_member ("name") : "Torrent");
            string state_value = info.has_member ("state") ? info.get_string_member ("state") : "Paused";
            int status_value = 0;
            if (state_value == "Checking") status_value = 2;
            else if (state_value == "Downloading") status_value = 4;
            else if (state_value == "Seeding") status_value = 6;
            else if (state_value == "Queued") status_value = 3;
            item.set_int_member ("status", status_value);
            item.set_double_member ("percentDone", info.has_member ("progress") ? info.get_double_member ("progress") / 100.0 : 0.0);
            item.set_double_member ("recheckProgress", 0.0);
            item.set_int_member ("eta", info.has_member ("eta") ? info.get_int_member ("eta") : -1);
            item.set_int_member ("haveValid", info.has_member ("total_done") ? info.get_int_member ("total_done") : 0);
            item.set_int_member ("sizeWhenDone", info.has_member ("total_size") ? info.get_int_member ("total_size") : 0);
            item.set_int_member ("uploadedEver", info.has_member ("total_uploaded") ? info.get_int_member ("total_uploaded") : 0);
            item.set_int_member ("rateDownload", info.has_member ("download_payload_rate") ? info.get_int_member ("download_payload_rate") : 0);
            item.set_int_member ("rateUpload", info.has_member ("upload_payload_rate") ? info.get_int_member ("upload_payload_rate") : 0);
            item.set_int_member ("peersConnected", info.has_member ("num_peers") ? info.get_int_member ("num_peers") : 0);
            item.set_int_member ("peersSendingToUs", 0);
            item.set_int_member ("peersGettingFromUs", 0);
            item.set_int_member ("error", 0);
            item.set_string_member ("errorString", "");
            item.set_array_member ("files", new Json.Array ());
            normalized.add_object_element (item);
        }
        return normalized;
    }

    public Json.Array all () {
        last_error = "";
        if (!detect_protocol ())
            return new Json.Array ();
        if (protocol == "deluge")
            return get_deluge_torrents ();
        Json.Object arguments = new Json.Object ();
        Json.Array fields = new Json.Array ();
        foreach (string field in torrent_fields)
            fields.add_string_element (field);
        arguments.set_array_member ("fields", fields);
        Json.Object? response = transmission_request ("torrent-get", arguments);
        if (response != null && response.has_member ("arguments")) {
            Json.Object result = response.get_object_member ("arguments");
            if (result.has_member ("torrents"))
                return result.get_array_member ("torrents");
        }
        return new Json.Array ();
    }

    private bool deluge_action (string method, int id, bool delete_data = false) {
        string? hash = deluge_hashes.get (id);
        if (hash == null) {
            last_error = "The selected torrent is no longer available on Deluge.";
            return false;
        }
        Json.Array args = new Json.Array ();
        if (method == "core.remove_torrent") {
            args.add_string_element (hash);
            args.add_boolean_element (delete_data);
        } else {
            Json.Array hashes = new Json.Array ();
            hashes.add_string_element (hash);
            args.add_array_element (hashes);
        }
        return deluge_request (method, args) != null;
    }

    private bool torrent_action (string method, int id) {
        Json.Object arguments = new Json.Object ();
        Json.Array ids = new Json.Array ();
        ids.add_int_element (id);
        arguments.set_array_member ("ids", ids);
        return transmission_request (method, arguments) != null;
    }

    public bool resume (int id) {
        last_error = "";
        if (!detect_protocol ()) return false;
        return protocol == "deluge" ? deluge_action ("core.resume_torrent", id) : torrent_action ("torrent-start", id);
    }

    public bool pause (int id) {
        last_error = "";
        if (!detect_protocol ()) return false;
        return protocol == "deluge" ? deluge_action ("core.pause_torrent", id) : torrent_action ("torrent-stop", id);
    }

    public bool remove (int id, bool delete_data = false) {
        last_error = "";
        if (!detect_protocol ()) return false;
        if (protocol == "deluge") return deluge_action ("core.remove_torrent", id, delete_data);
        Json.Object arguments = new Json.Object ();
        Json.Array ids = new Json.Array ();
        ids.add_int_element (id);
        arguments.set_array_member ("ids", ids);
        arguments.set_boolean_member ("delete-local-data", delete_data);
        return transmission_request ("torrent-remove", arguments) != null;
    }

    public bool add_from_magnet (string link) {
        last_error = "";
        if (!detect_protocol ()) return false;
        if (protocol == "deluge") {
            Json.Array args = new Json.Array ();
            args.add_string_element (link);
            args.add_object_element (new Json.Object ());
            return deluge_request ("core.add_torrent_magnet", args) != null;
        }
        Json.Object arguments = new Json.Object ();
        arguments.set_string_member ("filename", link);
        return transmission_request ("torrent-add", arguments) != null;
    }

    public bool add_from_file (uint8[] file, string filename = "torrent.torrent") {
        last_error = "";
        if (!detect_protocol ()) return false;
        string encoded = Base64.encode (file);
        if (protocol == "deluge") {
            Json.Array args = new Json.Array ();
            args.add_string_element (filename);
            args.add_string_element (encoded);
            args.add_object_element (new Json.Object ());
            return deluge_request ("core.add_torrent_file", args) != null;
        }
        Json.Object arguments = new Json.Object ();
        arguments.set_string_member ("metainfo", encoded);
        return transmission_request ("torrent-add", arguments) != null;
    }
}
