public class Main.HeaderBar : Gtk.HeaderBar {
    public Main.Window window { get; construct; }
    public Gtk.SearchEntry searchEntry;
    private Granite.Widgets.ModeButton statusFilter;

    public HeaderBar (Main.Window window) {
        Object (window: window);
    }

    construct {
        show_close_button = true;
        title = "Torrential Remote";

        Gtk.Button open_button = new Gtk.Button.from_icon_name ("document-open-symbolic", Gtk.IconSize.BUTTON);
        open_button.tooltip_text = "Add a torrent file";
        open_button.get_style_context ().add_class ("flat");
        open_button.clicked.connect (open_torrent_file);
        pack_start (open_button);

        Gtk.Button magnet_button = new Gtk.Button.from_icon_name ("insert-link-symbolic", Gtk.IconSize.BUTTON);
        magnet_button.tooltip_text = "Add a magnet link";
        magnet_button.get_style_context ().add_class ("flat");
        magnet_button.clicked.connect (open_magnet_dialog);
        pack_start (magnet_button);

        statusFilter = new Granite.Widgets.ModeButton ();
        statusFilter.append_text ("All");
        statusFilter.append_text ("Downloading");
        statusFilter.append_text ("Seeding");
        statusFilter.append_text ("Paused");
        statusFilter.selected = 0;
        statusFilter.notify["selected"].connect (apply_filter);
        set_custom_title (statusFilter);

        searchEntry = new Gtk.SearchEntry ();
        searchEntry.placeholder_text = "Search Torrents";
        searchEntry.width_chars = 18;
        searchEntry.search_changed.connect (apply_filter);
        pack_end (searchEntry);
    }

    private void apply_filter () {
        if (window.torrents == null)
            return;

        string query = searchEntry.text.strip ().casefold ();
        int selected_status = statusFilter.selected;
        window.torrents.set_filter_func ((row) => {
            Torrent.Row torrent_row = row as Torrent.Row;
            if (torrent_row == null)
                return false;
            bool matches_query = query == "" || torrent_row.title.label.casefold ().contains (query);
            bool matches_status = true;
            switch (selected_status) {
                case 1:
                    matches_status = torrent_row.status == Torrent.Statuses.DOWNLOAD ||
                        torrent_row.status == Torrent.Statuses.DOWNLOAD_WAIT;
                    break;
                case 2:
                    matches_status = torrent_row.status == Torrent.Statuses.SEED ||
                        torrent_row.status == Torrent.Statuses.SEED_WAIT;
                    break;
                case 3:
                    matches_status = torrent_row.status == Torrent.Statuses.STOPPED;
                    break;
                default:
                    break;
            }
            return matches_query && matches_status;
        });
        window.torrents.invalidate_filter ();
    }

    private void show_error (string message) {
        Gtk.MessageDialog dialog = new Gtk.MessageDialog (
            window, Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR,
            Gtk.ButtonsType.CLOSE, "%s", message
        );
        dialog.run ();
        dialog.destroy ();
    }

    private void open_torrent_file () {
        Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
            "Add Torrent", window, Gtk.FileChooserAction.OPEN,
            "_Cancel", Gtk.ResponseType.CANCEL,
            "_Open", Gtk.ResponseType.ACCEPT,
            null
        );
        chooser.set_select_multiple (false);
        Gtk.FileFilter torrent_filter = new Gtk.FileFilter ();
        torrent_filter.set_filter_name ("Torrent files");
        torrent_filter.add_mime_type ("application/x-bittorrent");
        chooser.add_filter (torrent_filter);
        if (chooser.run () == Gtk.ResponseType.ACCEPT) {
            try {
                uint8[] contents;
                string etag;
                chooser.get_file ().load_contents (null, out contents, out etag);
                Client.Model client = new Client.Model (window.selectedServer);
                if (!client.add_from_file (contents))
                    show_error (client.last_error);
                else
                    window.torrents.refresh_now ();
            } catch (Error error) {
                show_error (error.message);
            }
        }
        chooser.destroy ();
    }

    private void open_magnet_dialog () {
        Gtk.Dialog dialog = new Gtk.Dialog.with_buttons (
            "Add Magnet Link", window, Gtk.DialogFlags.MODAL,
            "_Cancel", Gtk.ResponseType.CANCEL,
            "_Add", Gtk.ResponseType.OK,
            null
        );
        Gtk.Entry entry = new Gtk.Entry ();
        entry.placeholder_text = "magnet:?xt=urn:btih:…";
        entry.activates_default = true;
        dialog.get_content_area ().set_spacing (12);
        dialog.get_content_area ().set_border_width (12);
        dialog.get_content_area ().pack_start (new Gtk.Label ("Magnet link:"), false, false, 0);
        dialog.get_content_area ().pack_start (entry, false, false, 0);
        dialog.set_default_response (Gtk.ResponseType.OK);
        dialog.set_response_sensitive (Gtk.ResponseType.OK, false);
        entry.changed.connect (() => {
            dialog.set_response_sensitive (Gtk.ResponseType.OK, entry.text.strip ().has_prefix ("magnet:?"));
        });
        string? clipboard_text = Gtk.Clipboard.get (Gdk.SELECTION_CLIPBOARD).wait_for_text ();
        if (clipboard_text != null && clipboard_text.has_prefix ("magnet:?"))
            entry.text = clipboard_text;
        dialog.show_all ();
        if (dialog.run () == Gtk.ResponseType.OK) {
            Client.Model client = new Client.Model (window.selectedServer);
            if (!client.add_from_magnet (entry.text.strip ()))
                show_error (client.last_error);
            else
                window.torrents.refresh_now ();
        }
        dialog.destroy ();
    }
}
