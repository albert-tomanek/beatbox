class Beatbox.DummyTile : Beatbox.Tile
{
	public override bool playing {
		get { return false; }
	}

	public DummyTile(MainWindow app)
	{
		Object(app: app);
	}

	public override void draw (Cairo.Context context, uint16 x, uint16 y)
	{
		set_context_rgb(context, TilePalette.RED);
		this.plot_shape(context, x, y);
		context.fill();

		Cairo.TextExtents extents;
		context.select_font_face ("Cantarell", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
		context.set_font_size(14);
		set_context_rgb(context, TilePalette.WHITE);

		context.text_extents("Dummy", out extents);
		context.move_to(x + (TILE_WIDTH/2) - (extents.width/2), y + (TILE_HEIGHT/2));
		context.show_text("Dummy");
	}

	public override void draw_border (Cairo.Context context, uint16 x, uint16 y)
	{
		set_context_rgb(context, (uint32) 0xffffffc0);
		this.plot_border(context, x, y);
		context.stroke();
	}
}
