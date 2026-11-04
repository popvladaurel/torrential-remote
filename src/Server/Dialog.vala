public class Server.Dialog : Granite.MessageDialog {
    public Dialog (Gee.ArrayList<Server.Model> serversList) {
        Object (
            primary_text: "Connect to a torrent server",
            secondary_text: "The server type can be detected automatically, or selected manually.",
            image_icon: GLib.Icon.new_for_string ("network-server"),
            buttons: Gtk.ButtonsType.NONE
        );
        set_modal (true);
        add_buttons ("Cancel", Gtk.ResponseType.CANCEL, "Save", Gtk.ResponseType.ACCEPT, null);

        Gtk.Grid grid = new Gtk.Grid ();
        grid.set_column_spacing (12);
        grid.set_row_spacing (10);
        grid.margin = 12;

        Gtk.Entry name_entry = new Gtk.Entry ();
        name_entry.hexpand = true;
        Gtk.Entry host_entry = new Gtk.Entry ();
        host_entry.hexpand = true;
        host_entry.placeholder_text = "hostname or IP address";
        Gtk.SpinButton port_entry = new Gtk.SpinButton.with_range (0, 65535, 1);
        port_entry.value = 0;
        port_entry.tooltip_text = "Leave at 0 to try the common Transmission and Deluge ports.";
        Gtk.Entry path_entry = new Gtk.Entry ();
        path_entry.hexpand = true;
        path_entry.text = "";
        Gtk.Entry username_entry = new Gtk.Entry ();
        username_entry.hexpand = true;
        Gtk.Entry password_entry = new Gtk.Entry ();
        password_entry.hexpand = true;
        password_entry.visibility = false;

        Gtk.ComboBoxText protocol_entry = new Gtk.ComboBoxText ();
        protocol_entry.append ("auto", "Detect automatically");
        protocol_entry.append ("transmission", "Transmission RPC");
        protocol_entry.append ("deluge", "Deluge Web API");
        protocol_entry.active_id = "auto";

        attach_field (grid, "Name", name_entry, 0);
        attach_field (grid, "Host", host_entry, 1);
        attach_field (grid, "Port (optional)", port_entry, 2);
        attach_field (grid, "RPC path (optional)", path_entry, 3);
        attach_field (grid, "Protocol", protocol_entry, 4);
        attach_field (grid, "Username", username_entry, 5);
        attach_field (grid, "Password", password_entry, 6);

        protocol_entry.changed.connect (() => {
            if (protocol_entry.active_id == "transmission") {
                port_entry.value = 9091;
                path_entry.text = "/transmission/rpc";
            } else if (protocol_entry.active_id == "deluge") {
                port_entry.value = 8112;
                path_entry.text = "/json";
            } else {
                port_entry.value = 0;
                path_entry.text = "";
            }
        });

        custom_bin.add (grid);
        get_widget_for_response (Gtk.ResponseType.ACCEPT).can_default = true;
        set_default_response (Gtk.ResponseType.ACCEPT);
        grid.show_all ();

        if (run () == Gtk.ResponseType.ACCEPT) {
            string chosen_protocol = protocol_entry.active_id ?? "auto";
            string chosen_port = port_entry.value_as_int == 0 ? "9091" : port_entry.value_as_int.to_string ();
            string chosen_path = path_entry.text.strip ();
            if (chosen_protocol == "auto" && chosen_path == "")
                chosen_path = "/transmission/rpc";
            if (chosen_protocol == "deluge" && chosen_path == "")
                chosen_path = "/json";
            Server.Model new_server = new Server.Model.for_saving (
                name_entry.text, host_entry.text, chosen_port, chosen_path,
                username_entry.text, password_entry.text, true, chosen_protocol
            );
            Server.Controller controller = new Server.Controller ();
            if (!controller.save (new_server)) {
                warning ("Could not save server configuration.");
            } else {
                // Probe now when automatic detection was requested so the UI
                // can report the detected server implementation immediately.
                Client.Model probe = new Client.Model (new_server);
                probe.all ();
                if (probe.last_error != "") {
                    Gtk.MessageDialog error_dialog = new Gtk.MessageDialog (
                        this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING,
                        Gtk.ButtonsType.CLOSE, "%s", probe.last_error
                    );
                    error_dialog.run ();
                    error_dialog.destroy ();
                }
            }
        }
        destroy ();
    }

    private void attach_field (Gtk.Grid grid, string label_text, Gtk.Widget widget, int row) {
        Gtk.Label label = new Gtk.Label (label_text + ":");
        label.halign = Gtk.Align.END;
        grid.attach (label, 0, row, 1, 1);
        grid.attach (widget, 1, row, 1, 1);
    }
}
