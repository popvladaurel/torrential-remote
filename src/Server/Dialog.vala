public class Server.Dialog : Granite.MessageDialog {
    public Dialog (Gee.ArrayList<Server.Model> serversList) {
        Object (
            primary_text: "Connect to a Transmission server",
            secondary_text: "Enter the server's Transmission RPC connection details.",
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
        Gtk.SpinButton port_entry = new Gtk.SpinButton.with_range (1, 65535, 1);
        port_entry.value = 9091;
        port_entry.tooltip_text = "Transmission RPC port (usually 9091).";
        Gtk.Entry path_entry = new Gtk.Entry ();
        path_entry.hexpand = true;
        path_entry.text = "/transmission/rpc";
        Gtk.Entry username_entry = new Gtk.Entry ();
        username_entry.hexpand = true;
        Gtk.Entry password_entry = new Gtk.Entry ();
        password_entry.hexpand = true;
        password_entry.visibility = false;

        attach_field (grid, "Name", name_entry, 0);
        attach_field (grid, "Host", host_entry, 1);
        attach_field (grid, "Port", port_entry, 2);
        attach_field (grid, "RPC path", path_entry, 3);
        attach_field (grid, "Username", username_entry, 4);
        attach_field (grid, "Password", password_entry, 5);

        custom_bin.add (grid);
        get_widget_for_response (Gtk.ResponseType.ACCEPT).can_default = true;
        set_default_response (Gtk.ResponseType.ACCEPT);
        grid.show_all ();

        if (run () == Gtk.ResponseType.ACCEPT) {
            string chosen_path = path_entry.text.strip ();
            if (chosen_path == "")
                chosen_path = "/transmission/rpc";
            Server.Model new_server = new Server.Model.for_saving (
                name_entry.text, host_entry.text, port_entry.get_value_as_int ().to_string (),
                chosen_path, username_entry.text, password_entry.text, true
            );
            Server.Controller controller = new Server.Controller ();
            if (!controller.save (new_server)) {
                warning ("Could not save server configuration.");
            } else {
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
