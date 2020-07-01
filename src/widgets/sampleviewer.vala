namespace Beatbox
{
	[GtkTemplate (ui = "/com/github/albert-tomanek/beatbox/sampleviewer.ui")]
	public class SampleViewer : Gtk.Overlay
	{
		private LoopTile? _loop;
		public  LoopTile? loop {
			get { return _loop; }
			set { on_release_sample(); _loop = value; on_new_sample(); }
		}

		public double zoom { get; set; }
		public double sec_pixels {
			get { return Math.exp2(zoom) * 100; }	// At zoom 0, 1s = 100px
		}

		int l_start {
			get {
				return int.max(0, (int) ((this.get_allocated_width() - ((this.loop == null) ? 0 : this.loop.duration / Gst.SECOND * sec_pixels)) / 2.0));
			}
		}

		int sample_width {	// Current width of the visualized sample in pixels (without padding)
			get {
				return (this.loop == null) ? 0 : (int) (this.loop.sample.duration * this.sec_pixels / (double) Gst.SECOND);
			}
		}

		/* Child widgets */
		[GtkChild] Gtk.DrawingArea sample_area;
		[GtkChild] Gtk.ScrolledWindow scrollwindow;
		[GtkChild] Gtk.Viewport viewport;

		[GtkChild] Gtk.Paned paned_l;
		[GtkChild] Gtk.Paned paned_r;

		[GtkChild] Gtk.Adjustment hscroll_adjustment;

		construct {
			this.notify["loop"].connect(this.on_new_sample);
			this.notify["zoom"].connect(this.on_zoom_changed);
			this.size_allocate.connect(this.on_zoom_changed);

			this.sample_area.draw.connect_after(this.render_sample);
		}

		void on_new_sample()
		{
			if (this.loop != null)
			{
				this.loop.sample.visu_updated.connect(this.sample_area.queue_draw);	// TODO: Disconnect after a the sample's been removed?
				this.zoom = this.loop._sv_zoom;
				this.on_zoom_changed();
			}
			
			this.sample_area.queue_draw();
		}

		void on_release_sample()
		{
			if (this.loop != null)
			{
				this.loop._sv_zoom = this.zoom;
			}
		}

		void on_zoom_changed()
		{
			this.sample_area.set_size_request(l_start + this.sample_width + l_start, -1);		// l_start is added for the empty padding at the start and end of the sample
			this.paned_l.set_position(l_start);
			this.paned_r.set_position((this.get_allocated_width() / 2) - l_start);

			if (this.loop != null)
				this.scrollwindow.hadjustment.value = this.sample_width * (this.loop.start_tm / (double) this.loop.sample.duration);
		}

		[GtkCallback]
		bool on_scroll(Gdk.EventScroll event)
		{
			if (this.loop == null) return false;

			if (event.get_source_device().input_source == Gdk.InputSource.MOUSE)	// Doesn't recognise my touchpad for some reason...
			{
				if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)
				{
					this.zoom = double.min(this.zoom - event.delta_y, 2);
				}
				else
				{
					this.scrollwindow.hadjustment.value += -event.delta_y * ((event.state & Gdk.ModifierType.SHIFT_MASK) != 0 ? 4 : 30);
					this.loop.start_tm = (uint64) ((this.scrollwindow.hadjustment.value / (double) sample_width) * this.loop.sample.duration);
				}
			}

			return false;
		}

		private Gst.ClockTime start_max {
			get { return this.loop.sample.duration - this.loop.duration; }
		}

		[GtkCallback]
		internal bool on_keypress(Gdk.EventKey event)
		{
			if (this.loop == null) return false;


			if (event.keyval == Gdk.Key.Page_Down)
			{
				this.loop.start_tm = (this.loop.start_tm - this.loop.duration > 0) ? this.loop.start_tm - this.loop.duration : 0;
			}
			else if (event.keyval == Gdk.Key.Page_Up)
			{
				this.loop.start_tm = (this.loop.start_tm + this.loop.duration < start_max) ? this.loop.start_tm + this.loop.duration : start_max;
			}
			else if (event.keyval == Gdk.Key.Home)
			{
				this.loop.start_tm = 0;
			}
			else if (event.keyval == Gdk.Key.End)
			{
				this.loop.start_tm = start_max;
			}
			else
			{
				return false;
			}

			this.on_zoom_changed();

			return true;	// Stop other handlers
		}

		public bool render_sample (Cairo.Context context)
		{
			if (this.loop != null)
			{
				set_context_rgb(context, TilePalette.WHITE);
				Sample.draw_amplitude(this.loop.sample.visu_l, this.loop.sample.visu_r, context, l_start, 0, this.sample_width, this.sample_area.get_allocated_height());
			}

			return true;
		}
	}
}
