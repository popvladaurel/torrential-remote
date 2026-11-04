public class Client.Model : Object {
    public string sessionId { get; set; default = ""; }
    public string url { get; set; }
    public string username { get; set; default = ""; }
    public string password { get; set; default = ""; }
    public string last_error { get; private set; default = ""; }

    private static string[] torrent_fields = {
        "id", "name", "eta", "status", "recheckProgress", "percentDone",
        "haveValid", "uploadedEver", "peersConnected", "peersSendingToUs",
        "peersGettingFromUs", "rateDownload", "rateUpload", "sizeWhenDone",
        "files", "error", "errorString"
    };

    public Model (Server.Model server) {
        url = server.rpc_url ();
        username = server.user;
        password = server.pass;
        sessionId = server.sessionId;
    }

    /* Shared RPC path for session negotiation, authentication, and errors. */
    private Json.Object? request (string method, Json.Object arguments) {
        last_error = "";
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
            if (message == null) {
                last_error = "The Transmission RPC URL is invalid.";
                return null;
            }
            message.set_request ("application/json", Soup.MemoryUse.COPY, payload.data);
            if (sessionId != "")
                message.request_headers.replace ("X-Transmission-Session-Id", sessionId);

            uint status = session.send_message (message);
            if (status == Soup.Status.CONFLICT) {
                string? new_session_id = message.response_headers.get_one ("X-Transmission-Session-Id");
                if (new_session_id == null || attempt != 0) {
                    last_error = "Transmission rejected the RPC session. Check the server URL and credentials.";
                    return null;
                }
                sessionId = new_session_id;
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
                string result = response.get_string_member ("result");
                if (result != "success") {
                    last_error = "Transmission RPC failed: %s".printf (result);
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

    public Json.Array all () {
        Json.Object arguments = new Json.Object ();
        Json.Array fields = new Json.Array ();
        foreach (string field in torrent_fields)
            fields.add_string_element (field);
        arguments.set_array_member ("fields", fields);
        Json.Object? response = request ("torrent-get", arguments);
        if (response != null && response.has_member ("arguments")) {
            Json.Object result = response.get_object_member ("arguments");
            if (result.has_member ("torrents"))
                return result.get_array_member ("torrents");
        }
        return new Json.Array ();
    }

    private bool torrent_action (string method, int id) {
        Json.Object arguments = new Json.Object ();
        Json.Array ids = new Json.Array ();
        ids.add_int_element (id);
        arguments.set_array_member ("ids", ids);
        return request (method, arguments) != null;
    }

    public bool resume (int id) {
        return torrent_action ("torrent-start", id);
    }

    public bool pause (int id) {
        return torrent_action ("torrent-stop", id);
    }

    public bool remove (int id, bool delete_data = false) {
        Json.Object arguments = new Json.Object ();
        Json.Array ids = new Json.Array ();
        ids.add_int_element (id);
        arguments.set_array_member ("ids", ids);
        arguments.set_boolean_member ("delete-local-data", delete_data);
        return request ("torrent-remove", arguments) != null;
    }

    public bool add_from_magnet (string link) {
        Json.Object arguments = new Json.Object ();
        arguments.set_string_member ("filename", link);
        return request ("torrent-add", arguments) != null;
    }

    public bool add_from_file (uint8[] file) {
        Json.Object arguments = new Json.Object ();
        arguments.set_string_member ("metainfo", Base64.encode (file));
        return request ("torrent-add", arguments) != null;
    }
}
