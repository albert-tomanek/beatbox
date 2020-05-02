using Math;

namespace Beatbox
{
	class LoopTile : Tile
	{
		string uri;
		float[] repr_l = new float[512];
		float[] repr_r = new float[512];

		public LoopTile(MainWindow app, string uri)
		{
			base(app);
			this.uri = uri;
			this.load_repr();
		}

		public override void start()
		{
			print(@"started $(uri)\n");
		}

		public override void stop()
		{
		}

		public override bool playing {
			get { return false; }
		}

		public override void draw (Cairo.Context context, uint16 x, uint16 y)
		{
			set_context_rgb(context, Palette.DARK_BLUE);
			context.set_line_join(Cairo.LineJoin.ROUND);
			this.plot_shape(context, x, y);
			context.fill();
		}

		public override void draw_border (Cairo.Context context, uint16 x, uint16 y)
		{
			set_context_rgb(context, Palette.LIGHT_BLUE);
			this.plot_border(context, x, y);
			context.stroke();
		}

		private void load_repr()
		{
			uint repr_idx = 0;

			/* Create elements */
			Gst.Pipeline pipeline = new Gst.Pipeline(null);
			Gst.Element uridecodebin  = Gst.ElementFactory.make ("uridecodebin", null);
			Gst.Element audioconvert  = Gst.ElementFactory.make ("audioconvert", null);
			Gst.Element level         = Gst.ElementFactory.make ("level", null);
			Gst.Element fakesink      = Gst.ElementFactory.make ("fakesink", null);

			/* Link elements */
			pipeline.add_many(uridecodebin, audioconvert, level, fakesink);
			audioconvert.link_many(level, fakesink);	// ?

			uridecodebin.pad_added.connect((pad) => { pad.link(audioconvert.get_static_pad("sink")); });
			uridecodebin.set("uri", this.uri);

			pipeline.set_state(Gst.State.PLAYING);
			pipeline.get_bus().message.connect((msg) => {
				print(msg.type.get_name()+"\n");
				if (msg.type == Gst.MessageType.ERROR)
				{Error error;string dbg; msg.parse_error(out  error, out dbg); print(error.message+"\n"+dbg+"\n");}
				if (msg.type == Gst.MessageType.ELEMENT && msg.get_structure() != null)
				{
					if (msg.get_structure().get_name() == "mean-amplitude" && repr_idx < 512)
					{
						msg.get_structure().get_uint("l_avg", out this.repr_l[repr_idx]);	// there's no `get_float` so we use `get_uint` which should be of the same size.
						msg.get_structure().get_uint("r_avg", out this.repr_r[repr_idx]);

						repr_idx++;
					}
				}
			});

			/* Wait for the stream to end */
			pipeline.get_bus().poll(Gst.MessageType.EOS, Gst.CLOCK_TIME_NONE);

			pipeline.set_state(Gst.State.NULL);
		}

		// private Loop loop;
		// public  Audio.SampleSrc player;

		// private float[] repr;	// A visual representation of the sample as values between -1 and 1 (?)

		// public LoopTile (OpenLoop.Loop loop)
		// {
		// 	this.loop = loop;
		// 	this.player = new Audio.SampleSrc (this.loop.orig_sample);

		// 	/* Generate the sample's visual representation */
		// 	this.repr = this.loop.orig_sample.visual_repr (TILE_WIDTH);
		// }

		// public override void start ()
		// {
		// 	this.player.start();
		// }

		// public override void stop ()
		// {
		// 	this.player.stop();
		// }

		// public override Gst.Element? gst_element { get { return this.player; } }

		// public override bool playing { get { return this.player.playing; } }

		// public override void draw (Cairo.Context context, uint16 x, uint16 y)
		// {
		// 	LoopTile.draw_tile    (this, context, TILE_BORDER_WIDTH + TILE_BORDER_OFFSET, TILE_BORDER_WIDTH + TILE_BORDER_OFFSET);
		// 	LoopTile.draw_progress(this, context, TILE_BORDER_WIDTH + TILE_BORDER_OFFSET, TILE_BORDER_WIDTH + TILE_BORDER_OFFSET);
		// 	LoopTile.draw_waveform(this, context, TILE_BORDER_WIDTH + TILE_BORDER_OFFSET, TILE_BORDER_WIDTH + TILE_BORDER_OFFSET);
		// }


		// private static void draw_waveform (LoopTile tile, Cairo.Context context, uint16 x, uint16 y)
		// {
		// 	/* Draw a representation of the sample's waveform */
		// 	uint16 center_y = y + (TILE_HEIGHT / 2);

		// 	Colours.set_context_rgb(context, (uint32) 0xffffffff);
		// 	context.set_line_join (Cairo.LineJoin.ROUND);

		// 	context.new_path ();
		// 	context.set_line_width (0.5);
		// 	context.move_to (x, center_y);

		// 	uint16 current_x = x;
		// 	foreach (float val in tile.repr)
		// 	{
		// 		context.line_to(current_x, center_y - (val * 1000 * TILE_HEIGHT * 0.5));
		// 		current_x++;
		// 	}

		// 	context.stroke();
		// }

		// private static void draw_progress (LoopTile tile, Cairo.Context context, uint16 x, uint16 y)
		// {
		// 	/* Draw the progress */
		// 	Colours.set_context_rgb(context, (Colours.LIGHT_BLUE & 0xffffff00) | (uint32) (0xff * Eyecandy.get_highlight_intensity()));
		// 	context.set_line_join(Cairo.LineJoin.MITER);
			//print(@"$(Eyecandy.get_highlight_intensity().to_string())\n");
		// 	context.new_path();
		// 	context.move_to(x + TILE_CORNER_RADIUS, y + TILE_HEIGHT);

		// 	context.arc     (x + TILE_CORNER_RADIUS, y + TILE_HEIGHT - TILE_CORNER_RADIUS, TILE_CORNER_RADIUS, Math.PI / 2, Math.PI);
		// 	context.line_to (x, y + TILE_CORNER_RADIUS);
		// 	context.arc     (x + TILE_CORNER_RADIUS, y + TILE_CORNER_RADIUS, TILE_CORNER_RADIUS, Math.PI, -Math.PI / 2);
		// 	context.line_to (x + TILE_WIDTH * tile.player.progress, y);
		// 	context.rel_line_to(0, TILE_HEIGHT);

		// 	context.close_path();
		// 	context.fill();
		// }

		// private static void draw_play (LoopTile tile, Cairo.Context context, uint16 x, uint16 y)
		// {
		// }
	}
}

namespace Eyecandy
{

	float get_highlight_intensity()
	{
		/* Returns a float between 0 and 1.	*
		 * Use this in GUI code to pulsate	*
		 * in time to the beat.				*/

		// var x = (double) App.metronome.beat_progress;
		// return (float) (cos(x * PI) / 7 + (6f / 7f));			// https://www.desmos.com/calculator/myz7wuhecm
		return 1;
	}
}
