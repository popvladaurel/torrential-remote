public class Client.View : Gtk.ListBox {
    public Server.Model server;
    public Client.Model client;
    private Gee.ArrayList<Torrent.Row> rows = new Gee.ArrayList<Torrent.Row> ();
    private uint refresh_source = 0;

    public View (Server.Model server) {
        this.server = server;
        client = new Client.Model (server);
        set_selection_mode (Gtk.SelectionMode.MULTIPLE);
        activate_on_single_click = false;
        button_press_event.connect (on_button_press);
        popup_menu.connect (on_popup_menu);
        refresh ();
        refresh_source = Timeout.add_seconds (2, () => {
            refresh ();
            return true;
        });
        destroy.connect (() => {
            if (refresh_source != 0)
                Source.remove (refresh_source);
        });
    }

    public void refresh () {
        Json.Array torrents = client.all ();
        Gee.HashSet<int> seen = new Gee.HashSet<int> ();
        foreach (Json.Node node in torrents.get_elements ()) {
            Torrent.Model torrent = new Torrent.Model (node);
            seen.add (torrent.id);
            Torrent.Row? row = find_row (torrent.id);
            if (row == null) {
                row = new Torrent.Row (torrent);
                row.pause.clicked.connect (() => {
                    bool success = row.status == Torrent.Statuses.STOPPED
                        ? client.resume ((int) row.id)
                        : client.pause ((int) row.id);
                    if (!success)
                        show_error (client.last_error);
                    else
                        refresh ();
                });
                rows.add (row);
                add (row);
                row.show_all ();
            } else {
                row.update_torrent (torrent);
            }
        }

        // Drop rows removed on the server instead of leaving stale entries.
        foreach (Torrent.Row row in rows.to_array ()) {
            if (!seen.contains ((int) row.id)) {
                remove (row);
                rows.remove (row);
            }
        }
        invalidate_filter ();
    }

    private Torrent.Row? find_row (int id) {
        foreach (Torrent.Row row in rows) {
            if (row.id == id)
                return row;
        }
        return null;
    }

    private void show_error (string message) {
        Gtk.Window? parent = get_toplevel () as Gtk.Window;
        Gtk.MessageDialog dialog = new Gtk.MessageDialog (
            parent, Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR,
            Gtk.ButtonsType.CLOSE, "%s", message
        );
        dialog.run ();
        dialog.destroy ();
    }

    private void remove_selected (bool delete_data) {
        List<weak Gtk.ListBoxRow> selected = get_selected_rows ();
        foreach (Gtk.ListBoxRow selected_row in selected) {
            Torrent.Row? row = selected_row as Torrent.Row;
            if (row != null && !client.remove ((int) row.id, delete_data)) {
                show_error (client.last_error);
                return;
            }
        }
        refresh ();
    }

    private bool on_popup_menu () {
        List<weak Gtk.ListBoxRow> selected = get_selected_rows ();
        if (selected.length () == 0)
            return false;

        Gtk.Menu menu = new Gtk.Menu ();
        Gtk.MenuItem pause_item = new Gtk.MenuItem.with_label ("Pause selected");
        pause_item.activate.connect (() => {
            foreach (Gtk.ListBoxRow selected_row in selected) {
                Torrent.Row? row = selected_row as Torrent.Row;
                if (row != null && row.status != Torrent.Statuses.STOPPED && !client.pause ((int) row.id)) {
                    show_error (client.last_error);
                    return;
                }
            }
            refresh ();
        });
        menu.append (pause_item);

        Gtk.MenuItem resume_item = new Gtk.MenuItem.with_label ("Resume selected");
        resume_item.activate.connect (() => {
            foreach (Gtk.ListBoxRow selected_row in selected) {
                Torrent.Row? row = selected_row as Torrent.Row;
                if (row != null && row.status == Torrent.Statuses.STOPPED && !client.resume ((int) row.id)) {
                    show_error (client.last_error);
                    return;
                }
            }
            refresh ();
        });
        menu.append (resume_item);

        Gtk.MenuItem remove_item = new Gtk.MenuItem.with_label ("Remove from server");
        remove_item.activate.connect (() => remove_selected (false));
        menu.append (remove_item);

        Gtk.MenuItem delete_item = new Gtk.MenuItem.with_label ("Remove and delete data");
        delete_item.activate.connect (() => {
            Gtk.MessageDialog confirm = new Gtk.MessageDialog (
                get_toplevel () as Gtk.Window, Gtk.DialogFlags.MODAL,
                Gtk.MessageType.WARNING, Gtk.ButtonsType.CANCEL,
                "Delete the selected torrent data from the remote server?"
            );
            confirm.add_button ("Delete", Gtk.ResponseType.ACCEPT);
            int response = confirm.run ();
            confirm.destroy ();
            if (response == Gtk.ResponseType.ACCEPT)
                remove_selected (true);
        });
        menu.append (delete_item);
        menu.show_all ();
        menu.popup (null, null, null, 0, Gtk.get_current_event_time ());
        return true;
    }

    private bool on_button_press (Gdk.EventButton event) {
        if (event.type != Gdk.EventType.BUTTON_PRESS || event.button != Gdk.BUTTON_SECONDARY)
            return false;
        Gtk.ListBoxRow? clicked = get_row_at_y ((int) event.y);
        if (clicked != null) {
            bool already_selected = false;
            foreach (Gtk.ListBoxRow row in get_selected_rows ()) {
                if (row == clicked) {
                    already_selected = true;
                    break;
                }
            }
            if (!already_selected) {
                foreach (Gtk.ListBoxRow row in get_selected_rows ())
                    unselect_row (row);
                select_row (clicked);
            }
        }
        return on_popup_menu ();
    }
}
