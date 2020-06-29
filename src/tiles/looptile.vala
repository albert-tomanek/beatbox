using Math;

namespace Beatbox
{
	public class LoopTile : Tile
	{
		public Sample sample { get; private set; }

		public double start_tm { get; set; default = 0; }		// As a fraction of duration of the whole sample
		public double duration { get; set; default = 4; }		// in seconds

		GES.Layer layer;
		GES.UriClip? clip = null;
		GES.UriClip? old_clip = null;	// You briefly have two while dragging

		Gst.ClockID? end_notif_id = null;

		public LoopTile(MainWindow app, string uri)
		{
			base(app);
			this.sample = new Sample(uri);
			this.sample.visu_updated.connect(() => {
				this.host.queue_draw();
			});

			this.layer = new GES.Layer();
			app.timeline.add_layer(this.layer);
		}

		construct
		{
			this.attached.connect(this.on_attached);	// I'd make this a closure, but the closure had an unnecessary reference to this that kept it from being destructed.
			this.detached.connect((host) => {
				this.old_clip = this.clip;
				this.clip = null;
			});

			this.notify["start_tm"].connect(this.host.queue_draw);
			this.notify["duration"].connect(this.host.queue_draw);
		}

		~LoopTile()
		{
			this.layer.remove_clip(this.clip);
			if (this.old_clip != null) {
				this.layer.remove_clip(this.old_clip);
			}
			app.timeline.remove_layer(this.layer);
		}

		void on_attached()
		{
			this.clip = new GES.UriClip(this.sample.uri);
			this.layer.add_clip(this.clip);

			this.clip.start    = 4 * app.beat_duration * host.bar_no;
			this.clip.duration = 4 * app.beat_duration;

			app.timeline.commit();

			if (this.old_clip != null)
			{
				this.layer.remove_clip(this.old_clip);
				this.old_clip = null;
				app.timeline.commit();
			}
		}

		public override void start()
		{
			print("started\n");

			/* Here we set up to get notified at the time when the clip *should* finish. */
			// this.end_notif_id = app.timeline.get_clock().new_single_shot_id(app.timeline.get_clock().get_time() + this.clip.duration);
			// Gst.Clock.id_wait_async(this.end_notif_id, () => {
			// 	print(@"=> Should have finished\n");
			// 	return false;
			// });
		}

		public override void stop()
		{
			print("stopped\n");
			// this.clip.duration = app.timeline.get_clock().get_time() - this.clip.start;

			/* Unschedule the finished clip callback bc it happened early. */
			// Gst.Clock.id_unschedule(this.end_notif_id);
			this.end_notif_id = null;
		}

		public override bool playing {
			get { return this.clip != null; }
		}

		public override void draw (Cairo.Context context, uint16 x, uint16 y)
		{
			set_context_rgb(context, TilePalette.DARK_BLUE);
			context.set_line_join(Cairo.LineJoin.ROUND);
			this.plot_shape(context, x, y);
			context.fill();

			double progress = app.timeline.get_clock() == null ? 0 : (get_running_time(app.timeline) / (double) this.clip.duration - this.clip.start / (double) this.clip.duration).clamp(0, 1);
			this.draw_progress(context, x, y, (uint32) 0x1374c5ff, progress);

			set_context_rgb(context, TilePalette.WHITE);
			Sample.draw_amplitude(this.sample, context, x, y, TILE_WIDTH, TILE_HEIGHT);
		}

		public override void draw_border (Cairo.Context context, uint16 x, uint16 y)
		{
			set_context_rgb(context, TilePalette.LIGHT_BLUE);
			this.plot_border(context, x, y);
			context.stroke();
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
