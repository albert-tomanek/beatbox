namespace Beatbox
{
	[GtkTemplate (ui = "/com/github/albert-tomanek/beatbox/sampleviewer.ui")]
	public class SampleViewer : Gtk.Overlay
	{
		public   LoopTile? loop { get; set; }

		public double zoom {
			get { return (this.loop != null) ? this.loop._sv_zoom : 0; }
			set { this.loop._sv_zoom = value; }
		}
		public double sec_pixels {
			get { return Math.exp2(zoom) * 100; }	// At zoom 0, 1s = 100px
		}

		int l_start {
			get {
				return int.max(0, (int) ((this.get_allocated_width() - clip_width) / 2.0));
			}
		}

		int sample_width {	// Current width of the visualized sample in pixels (without padding)
			get {
				return (this.loop == null) ? 0 : (int) (this.loop.sample.duration * this.sec_pixels / (double) Gst.SECOND);
			}
		}

		int clip_width {
			get {
				return (this.loop == null) ? 0 : (int) ((this.loop.duration / (double) Gst.SECOND) * sec_pixels);
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
			this.size_allocate.connect(this.on_zoom_changed);

			this.sample_area.draw.connect_after(this.render_sample);
		}

		void on_new_sample()
		{
			if (this.loop != null)
			{
				this.loop.sample.visu_updated.connect(this.sample_area.queue_draw);	// If the whole sample's visu is still loading. // TODO: Disconnect after a the sample's been removed?
				this.loop.notify["duration"].connect(this.on_zoom_changed);

				this.on_zoom_changed();			// Change to the new tile's zoom, start and duration.
			}

			this.sample_area.queue_draw();
		}

		void on_zoom_changed()
		{message("Zoom changed");
			this.sample_area.set_size_request(l_start + this.sample_width + clip_width + l_start, -1);		// l_start is added for the empty padding at the start and end of the sample, so that it's in the middle of the screen. clip_width is added so that you can start with the end of the sample.
			this.paned_l.set_position(l_start);
			this.paned_r.set_position((this.get_allocated_width() / 2) - l_start);
			this.queue_resize();	// Gotta do this else it doesn;t resize straight away

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
					this.on_zoom_changed();
				}
				else
				{
					this.scrollwindow.hadjustment.value += -event.delta_y * ((event.state & Gdk.ModifierType.SHIFT_MASK) != 0 ? 4 : 30);
					int pane_width = (this.get_allocated_width() - clip_width) / 2;
					double start_frac  = (this.scrollwindow.hadjustment.value + l_start - pane_width) / (double) sample_width;
					//                                                            ⮴ l_start is for the emptiness to the left of the waveform. Doesn't go below 0. pane_width is for the width of the Gtk.Paned, which can go below 0 if the utilised clip is wider than the SampleViewer widget.
					this.loop.start_tm = (uint64)(this.loop.sample.duration * start_frac);
				}
			}

			return false;
		}

		private Gst.ClockTime start_max {
			get { return this.loop.sample.duration; }
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

		Gdk.Pixbuf? render_cache = null;

		public bool render_sample (Cairo.Context context)
		{
			if (this.loop != null)
			{
				int x = l_start, y = 0, w = this.sample_width, h = this.sample_area.get_allocated_height();

				if (render_cache != null)
				{
					message("Render cache present");
					if (render_cache.width  == w &&
						render_cache.height == h)
					{
						message("Used cached image");
						Gdk.cairo_set_source_pixbuf(context, render_cache, x, y);
						return true;
					}
				}

				set_context_rgb(context, TilePalette.WHITE);
				Sample.draw_amplitude(this.loop.sample.visu_l, this.loop.sample.visu_r, context, x, y, w, h);

				/* Cache the waveform so we don't have to draw it each time */
				this.render_cache = Gdk.pixbuf_get_from_surface(context.get_target(), x, y, w, h);
			}

			return true;
		}
	}
}
