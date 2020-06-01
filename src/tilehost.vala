enum DndTargetType {
	TILE_PTR,
	URI,
}

const Gtk.TargetEntry[] gtk_targetentries = {
	{"com.github.albert-tomanek.beatbox.tile_instance_ptr", Gtk.TargetFlags.SAME_APP, DndTargetType.TILE_PTR},
	{"text/uri-list", 0, DndTargetType.URI},
};

public class Beatbox.TileHost : Gtk.DrawingArea
{
	weak MainWindow app;

	private Tile? tile_;
	public  Tile? tile {
		set {
			if (tile_ != null)
				tile_.detached();

			tile_ = value;

			if (tile_ != null)
				tile_.attached(this);

			this.queue_draw();
		}
		get {
			return tile_;
		}
	}

	public uint bar_no   { get; set; }
	public uint track_no { get; set; }

	public signal void uri_dropped(TileHost host, string uri);
	private bool tile_being_dragged = false;

	public TileHost(MainWindow app)
	{
		this.app = app;

		this.can_focus = true;
		this.set_size_request(
			TILE_WIDTH + (2 * TILE_BORDER_OFFSET) + (2 * TILE_BORDER_WIDTH),
			TILE_WIDTH + (2 * TILE_BORDER_OFFSET) + (2 * TILE_BORDER_WIDTH)
		);

		/* Listen for events */
		this.add_events (
			Gdk.EventMask.BUTTON_PRESS_MASK |
			Gdk.EventMask.BUTTON_RELEASE_MASK
		);

		this.button_release_event.connect(this.on_click);

		/* Drag and Drop */
		Gtk.drag_dest_set(this, Gtk.DestDefaults.MOTION, gtk_targetentries, Gdk.DragAction.MOVE);

		this.notify["tile"].connect(this.on_tile_changed);

		/* Queue a redraw every 50 milliseconds */
		Timeout.add(1000/60, () => { this.queue_draw(); return true; });
	}

	void on_tile_changed()
	{
		if (this.tile != null)
		{
			Gtk.drag_source_set(this, Gdk.ModifierType.BUTTON1_MASK, gtk_targetentries, Gdk.DragAction.MOVE);

			this.tile.notify["selected"].connect(() => { this.queue_draw(); });
		}
		else
		{
			Gtk.drag_source_unset(this);
		}
	}

	/* User interaction handelers */

	private bool on_click(Gdk.EventButton event)
	{
		this.grab_focus();

		Gdk.ModifierType mods;
		event.get_state(out mods);

		/* Change with what is selected */
		bool ctrl_key = (mods & Gdk.ModifierType.CONTROL_MASK) != 0;
		bool right_click = (event.button == 3);

		if (!right_click)
		{
			if (ctrl_key)
			{
				if (this.tile != null)
					this.tile.selected = !this.tile.selected;
			}
			else
			{
				app.foreach_tile((tile) => { tile.selected = false; });
				if (this.tile != null)
					this.tile.selected = true;
			}
		}
		else
		{
			if (this.tile != null)
				this.tile.selected = true;
		}

		/* Do stuff */
		if (event.button == 3)
		{
			this.on_rclick(event);
		}

		return true;	// true to stop other handlers from being invoked for the event.
	}

	private void on_rclick(Gdk.EventButton event)
	{
		var context_menu = new Gtk.Menu();						// Because context_menu is a local variable, it would be destroyed after the current method ended. Therefore we have to attach it to a widget so that it is destroyed only once the widget is destoryed.
		context_menu.attach_to_widget(this, null);

		var item_delete_tile = new Gtk.MenuItem.with_mnemonic("_Delete");
		item_delete_tile.activate.connect(() => {
			app.foreach_tile((tile) => {
				if (tile.selected)
					tile.host.tile = null;	// Remove the tile from its host, hence deleting it.
			});
		});
		context_menu.append(item_delete_tile);

		context_menu.show_all();
		context_menu.popup_at_pointer(event);
	}

	/* Drag and drop -- source callbacks */

	internal override override void drag_begin (Gdk.DragContext context)
	{
		this.tile_being_dragged = true;

		var sfc = new Cairo.ImageSurface(Cairo.Format.ARGB32, TILE_WIDTH, TILE_HEIGHT);
        this.tile.draw(new Cairo.Context(sfc), 0, 0);

		Gtk.drag_set_icon_pixbuf(context, Gdk.pixbuf_get_from_surface(sfc, 0, 0, TILE_WIDTH, TILE_HEIGHT), TILE_WIDTH/2, TILE_HEIGHT/2);
	}

	internal override void drag_end (Gdk.DragContext context)
	{
		this.tile_being_dragged = false;
	}

	internal override void drag_data_get (Gdk.DragContext context, Gtk.SelectionData selection_data, uint target_type, uint time)
	{
		switch (target_type)
		{
			case DndTargetType.TILE_PTR:
				this.tile.@ref();					// Manually increase the reference count to account for the pointer that we're sending as the selection data.
				Tile[] _tile = {this.tile};
				selection_data.set(selection_data.get_target(), (int) sizeof(void *) * 8, (uint8[])(_tile));
				break;
			default:
				break;
		}
	}

	/* Drag and drop -- destination callbacks */
	private static Gdk.Atom? find_atom_with_name(string name, List<Gdk.Atom> list)
	{
		foreach (var atom in list)
		{
			if (atom.name() == name) return atom;
		}

		return null;
	}

	internal override bool drag_drop (Gdk.DragContext context, int x, int y, uint time)
	{
		/* Don't accept a drop of we're already hosting a tile. */
		if (this.tile != null) return false;

		if (context.list_targets() == null) return false;

		Gdk.Atom? target_type = null;
		if (target_type == null)
			target_type = find_atom_with_name("com.github.albert-tomanek.beatbox.tile_instance_ptr", context.list_targets());	//.nth_data(DndTargetType.TILE_PTR);
		if (target_type == null)
			target_type = find_atom_with_name("text/uri-list", context.list_targets());
		if (target_type == null)
			return false;	// No compatable target type

		/* Request the data from the source. */
		Gtk.drag_get_data (
			this,			// will receive 'drag_data_received' signal
			context,		// represents the current state of the DnD
			target_type,	// the target type we want
			time			// time stamp
		);

		return true;
	}

	internal override void drag_data_received (Gdk.DragContext context, int x, int y, Gtk.SelectionData selection_data, uint target_type, uint time)
	{
		bool delete_source = false, success = true;

		/* Deal with what we are given from source */
		if (selection_data.get_length() >= 0)
		{
			switch (target_type) {
				case DndTargetType.TILE_PTR:
				{
					Tile tile = ((Tile[]) selection_data.get_data())[0];
					tile.unref();

					if (tile.host != null)			// WARNING: The tile will be removed from its old host regardless of whether `context.get_suggested_action() == Gdk.DragAction.MOVE` or not.
						tile.host.tile = null;

					this.tile = tile;
					break;
				}
				case DndTargetType.URI:
				{
					var uri = selection_data.get_uris()[0];
					this.uri_dropped(this, uri);
					break;
				}
				default:
					GLib.printerr("Incompatable data dropped.\n");
					success = false;
					break;
			}
		}

		Gtk.drag_finish (context, success, delete_source, time);
	}

	/* Drawing */

	public override bool draw (Cairo.Context context)
	{
		if (this.tile != null/* && !this.tile_being_dragged*/)
		{
			this.tile.draw(context, TILE_BORDER_WIDTH + TILE_BORDER_OFFSET, TILE_BORDER_WIDTH + TILE_BORDER_OFFSET);

			if (this.tile != null) {
				if (this.tile.selected)
					this.tile.draw_border(context, TILE_BORDER_WIDTH + TILE_BORDER_OFFSET, TILE_BORDER_WIDTH + TILE_BORDER_OFFSET);
			}
		}
		else
		{
			/* If we don't contain any tile, draw us empty */
			context.set_source_rgba(0.5, 0.5, 0.5, 0.2);
			context.set_line_join(Cairo.LineJoin.ROUND);

			Tile.plot_shape(context, TILE_BORDER_WIDTH + TILE_BORDER_OFFSET, TILE_BORDER_WIDTH + TILE_BORDER_OFFSET);

			context.fill();
		}

		return true;
	}
}
