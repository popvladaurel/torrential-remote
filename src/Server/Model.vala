public class Server.Model : Object {
    public string name { get; set; default = "Default"; }
    public string host { get; set; default = "localhost"; }
    public string port { get; set; default = "9091"; }
    public string path { get; set; default = "/transmission/rpc"; }
    public string user { get; set; default = ""; }
    public string pass { get; set; default = ""; }
    public bool auto { get; set; default = false; }
    public string url { get; set; default = ""; }
    public string sessionId { get; set; default = ""; }
    // auto | transmission | deluge
    public string protocol { get; set; default = "auto"; }
    public bool is_default { get; set; default = false; }

    public Model () {
    }

    public Model.for_saving (string? newName, string? newHost, string? newPort,
                             string? newPath, string? newUser, string? newPass,
                             bool newAuto, string newProtocol = "auto") {
        name = newName ?? "Default";
        host = newHost ?? "localhost";
        port = newPort ?? "9091";
        path = newPath ?? "/transmission/rpc";
        user = newUser ?? "";
        pass = newPass ?? "";
        auto = newAuto;
        protocol = newProtocol;
        url = rpc_url ();
    }

    public string rpc_url_for (string selected_protocol, string? selected_port = null) {
        string scheme = host.has_prefix ("https://") || host.has_prefix ("http://") ? "" : "http://";
        string effective_port = selected_port ?? port;
        string endpoint = path;
        if (selected_protocol == "deluge") {
            if (endpoint == "" || endpoint == "/transmission/rpc")
                endpoint = "/json";
        } else if (endpoint == "" || endpoint == "/json") {
            endpoint = "/transmission/rpc";
        }
        if (!endpoint.has_prefix ("/"))
            endpoint = "/" + endpoint;
        return "%s%s:%s%s".printf (scheme, host, effective_port, endpoint);
    }

    public string rpc_url () {
        string selected_protocol = protocol == "auto" ? "transmission" : protocol;
        return rpc_url_for (selected_protocol);
    }

    public bool equals (Model other) {
        return name == other.name && host == other.host && port == other.port && path == other.path;
    }
}
