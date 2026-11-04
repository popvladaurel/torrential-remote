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

    // Loading a server should not initiate network traffic.
    public Model () {
    }

    public Model.for_saving (string? newName, string? newHost, string? newPort,
                             string? newPath, string? newUser, string? newPass,
                             bool newAuto) {
        name = newName ?? "Default";
        host = newHost ?? "localhost";
        port = newPort ?? "9091";
        path = newPath ?? "/transmission/rpc";
        user = newUser ?? "";
        pass = newPass ?? "";
        auto = newAuto;
        url = rpc_url ();
    }

    public string rpc_url () {
        string scheme = host.has_prefix ("https://") || host.has_prefix ("http://") ? "" : "http://";
        string normalized_path = path.has_prefix ("/") ? path : "/" + path;
        return "%s%s:%s%s".printf (scheme, host, port, normalized_path);
    }

    public bool equals (Model other) {
        return name == other.name && host == other.host && port == other.port && path == other.path;
    }
}
