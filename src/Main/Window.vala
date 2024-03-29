public class Main.Window : Gtk.ApplicationWindow {

	public Settings settings;
	public Main.HeaderBar headerBar;
	private Gtk.Box box;
	public Gtk.ScrolledWindow scroll;
	public Server.Model server;
	public bool dark_theme { get; set; }
	public Server.Model selectedServer;
	public Client.View torrents;

	construct {
		scroll = new Gtk.ScrolledWindow(null, null);
		box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
		settings = new Settings ("com.github.popvladaurel.torrential-remote");

		move (settings.get_int ("window-pos-x"), settings.get_int ("window-pos-y"));
		resize (settings.get_int ("window-width"), settings.get_int ("window-height"));
		dark_theme = settings.get_boolean ("dark-theme");
		headerBar = new Main.HeaderBar (this);

		delete_event.connect (e => {
	 		return before_destroy ();
		});
	}

	public Window (Gee.ArrayList<Server.Model> serversListArray) {
		Gtk.Paned paned = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);

		Gtk.Box box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
		Granite.Widgets.SourceList serversList = new Granite.Widgets.SourceList ();
		serversList.vexpand = true;
		serversList.set_margin_start(5);

		foreach (Server.Model server in serversListArray) {
			serversList.root.add (new Server.Item (server));
		}
		
		box.pack_start(serversList, true, true, 0);

		Gtk.ActionBar actions = new Gtk.ActionBar();
		Gtk.Button plus = new Gtk.Button.from_icon_name ("list-add", Gtk.IconSize.SMALL_TOOLBAR);

		plus.clicked.connect (() => {
			Server.Controller serverController = new Server.Controller ();
			Server.Dialog dialog = new Server.Dialog (serversListArray);
			//  serversListArray = serverController.all ();
		});

		Gtk.Button minus = new Gtk.Button.from_icon_name ("list-remove", Gtk.IconSize.SMALL_TOOLBAR);

		minus.clicked.connect (() => {
			Server.Controller serverController = new Server.Controller ();
			serverController.delete (((Server.Item) serversList.selected).server);
		});

		actions.pack_start(plus);
		actions.pack_start(minus);
		box.pack_end(actions, false, true, 0);


		//TODO restore pane position from gsettings
		paned.position = 150;
		paned.wide_handle = true;
		paned.pack1 (box, false, false);
		
		//TODO Autoconnect to the default server
		selectedServer = serversListArray.get (0);
		torrents = new Client.View (selectedServer);
		scroll.add(torrents);
		paned.pack2(scroll, false, false);
		set_titlebar(headerBar);
		add(paned);
		show_all();
		Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = dark_theme;


	}

	public bool before_destroy () {
		int width, height, x, y;

		get_size (out width, out height);
		get_position (out x, out y);
		
		//TODO get pane position and save it

		settings.set_int ("window-pos-x", x);
		settings.set_int ("window-pos-y", y);
		settings.set_int ("window-width", width);
		settings.set_int ("window-height", height);
		settings.set_boolean ("dark-theme", dark_theme);

		return false;
	}	
}
