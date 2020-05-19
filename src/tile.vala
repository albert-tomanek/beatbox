namespace Beatbox
{
	const uint16 TILE_WIDTH  = 96;
	const uint16 TILE_HEIGHT = 96;
	const uint16 TILE_CORNER_RADIUS = 8;
	const uint16 TILE_BORDER_OFFSET = 4;	// How many pixels between the tile and its border
	const uint16 TILE_BORDER_WIDTH  = 2;	// How wide the tile border is
	const uint16 TILE_SPACING = 4;

	namespace Palette
	{
		const uint32 LIGHT_BLUE = 0x38acffc0;
		const uint32 DARK_BLUE  = 0x124780ff;
		const uint32 BLACK      = 0x101010ff;
		const uint32 WHITE      = (uint32) 0xffffffff;
		const uint32 RED        = (uint32) 0xcb2d2eff; //cd3436ff
	}

	void set_context_rgb(Cairo.Context context, uint32 colour)
	{
		context.set_source_rgba(((colour & 0xff000000) >> 24) / 255f, ((colour & 0x00ff0000) >> 16) / 255f, ((colour & 0x0000ff00) >> 8) / 255f, ((colour & 0x000000ff) >> 0) / 255f);
	}

	abstract class Tile : Object
	{
		public weak TileHost? host { get; private set; }
		public bool selected { get; set; }

		public signal void attached(TileHost host);
		public signal void detached();	// Called BEFORE the tile gets actually detached in real. TODO: Might do a race condition if any detached handlers are slower than the actual reassignment of the variable in the TileHost.

		public virtual void start() { }
		public virtual void stop()  { }
		public abstract bool playing { get; }

		protected weak MainWindow app;

		public Tile(MainWindow app)
		{
			this.app = app;

			this.attached.connect((host) => {this.host = host;});
			this.detached.connect(()     => {this.host = null;});
		}

		public abstract void draw        (Cairo.Context context, uint16 x, uint16 y);
		public abstract void draw_border (Cairo.Context context, uint16 x, uint16 y);

		protected static void plot_border (Cairo.Context context, uint16 x, uint16 y)
		{
			context.new_path();
			context.set_line_width (TILE_BORDER_WIDTH);
			context.move_to(x + TILE_BORDER_OFFSET, y + TILE_CORNER_RADIUS);

			context.arc     (x + TILE_CORNER_RADIUS, y + TILE_CORNER_RADIUS, TILE_CORNER_RADIUS - TILE_BORDER_OFFSET, Math.PI, -Math.PI / 2);
			context.line_to (x + TILE_WIDTH - TILE_CORNER_RADIUS, y + TILE_BORDER_OFFSET);
			context.arc     (x + TILE_WIDTH - TILE_CORNER_RADIUS, y + TILE_CORNER_RADIUS, TILE_CORNER_RADIUS - TILE_BORDER_OFFSET, -Math.PI / 2, 0);
			context.line_to (x + TILE_WIDTH - TILE_BORDER_OFFSET, y + TILE_HEIGHT - TILE_CORNER_RADIUS);
			context.arc     (x + TILE_WIDTH - TILE_CORNER_RADIUS, y + TILE_HEIGHT - TILE_CORNER_RADIUS, TILE_CORNER_RADIUS - TILE_BORDER_OFFSET, 0, Math.PI / 2);
			context.line_to (x + TILE_CORNER_RADIUS, y + TILE_HEIGHT - TILE_BORDER_OFFSET);
			context.arc     (x + TILE_CORNER_RADIUS, y + TILE_HEIGHT - TILE_CORNER_RADIUS, TILE_CORNER_RADIUS - TILE_BORDER_OFFSET, Math.PI / 2, Math.PI);
			context.close_path();

			context.stroke();
		}

		public static void plot_shape(Cairo.Context context, uint16 x, uint16 y)	// TileHost needs this too
		{
			context.new_path();
			context.move_to (x, y + TILE_CORNER_RADIUS);
			context.arc     (x + TILE_CORNER_RADIUS, y + TILE_CORNER_RADIUS, TILE_CORNER_RADIUS, Math.PI, -Math.PI / 2);
			context.line_to (x + TILE_WIDTH - TILE_CORNER_RADIUS, y);
			context.arc     (x + TILE_WIDTH - TILE_CORNER_RADIUS, y + TILE_CORNER_RADIUS, TILE_CORNER_RADIUS, -Math.PI / 2, 0);
			context.line_to (x + TILE_WIDTH, y + TILE_HEIGHT - TILE_CORNER_RADIUS);
			context.arc     (x + TILE_WIDTH - TILE_CORNER_RADIUS, y + TILE_HEIGHT - TILE_CORNER_RADIUS, TILE_CORNER_RADIUS, 0, Math.PI / 2);
			context.line_to (x + TILE_CORNER_RADIUS, y + TILE_HEIGHT);
			context.arc     (x + TILE_CORNER_RADIUS, y + TILE_HEIGHT - TILE_CORNER_RADIUS, TILE_CORNER_RADIUS, Math.PI / 2, Math.PI);
			context.close_path();
		}

		public static void draw_progress(Cairo.Context context, uint16 x, uint16 y, uint32 color, double progress)
		{
			plot_shape(context, x, y);
			context.clip();

			context.rectangle(x, y, progress * TILE_WIDTH, TILE_HEIGHT);
			set_context_rgb(context, color);
			context.fill();
		}
	}
}
