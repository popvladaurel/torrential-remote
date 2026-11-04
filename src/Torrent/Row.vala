public class Torrent.Row : Gtk.ListBoxRow {
    public int64 id { get; set; }
    public Gtk.Grid grid;
    public Gtk.Image icon;
    public Gtk.Label title { get; set; }
    public Gtk.Label stats;
    public Gtk.ProgressBar progress;
    public Gtk.Button pause;
    public Gtk.Label state;
    public int status;
    public Torrent.Model torrent;

    private const string PAUSE_ICON_NAME = "media-playback-pause-symbolic";
    private const string RESUME_ICON_NAME = "media-playback-start-symbolic";

    public signal void torrent_removed ();

    public Row (Torrent.Model torrent) {
        this.torrent = torrent;
        id = torrent.id;
        status = torrent.status;
        grid = new Gtk.Grid ();
        grid.margin = 12;
        grid.margin_bottom = margin_top = 6;
        grid.column_spacing = 12;
        grid.row_spacing = 3;
        icon = new Gtk.Image.from_gicon (torrent.icon (), Gtk.IconSize.DIALOG);
        title = new Gtk.Label (torrent.title ());
        title.halign = Gtk.Align.START;
        title.get_style_context ().add_class ("h3");
        stats = new Gtk.Label ("TODO");
        stats.halign = Gtk.Align.START;
        stats.use_markup = true;
        progress = new Gtk.ProgressBar ();
        progress.hexpand = true;
        pause = new Gtk.Button ();
        pause.get_style_context ().add_class ("flat");
        state = new Gtk.Label ("TODO");
        state.halign = Gtk.Align.START;
        state.use_markup = true;
        grid.attach (icon, 0, 0, 1, 4);
        grid.attach (title, 1, 0, 1, 1);
        grid.attach (stats, 1, 1, 1, 1);
        grid.attach (pause, 2, 1, 1, 4);
        grid.attach (progress, 1, 2, 1, 1);
        grid.attach (state, 1, 3, 1, 1);
        add (grid);
        update_torrent (torrent);
        show_all ();
    }

    public void update_torrent (Torrent.Model updated) {
        torrent = updated;
        id = updated.id;
        status = updated.status;
        title.label = updated.title ();
        stats.set_markup ("<small>%s</small>".printf (Markup.escape_text (updated.stats ())));
        state.set_markup ("<small>%s</small>".printf (Markup.escape_text (updated.state ())));
        progress.fraction = updated.status == Torrent.Statuses.CHECK
            ? updated.recheckProgress : updated.percentDone;
        if (updated.status == Torrent.Statuses.STOPPED) {
            pause.set_image (new Gtk.Image.from_icon_name (RESUME_ICON_NAME, Gtk.IconSize.BUTTON));
            pause.tooltip_text = "Resume torrent";
        } else {
            pause.set_image (new Gtk.Image.from_icon_name (PAUSE_ICON_NAME, Gtk.IconSize.BUTTON));
            pause.tooltip_text = "Pause torrent";
        }
        pause.show_all ();
    }
}
