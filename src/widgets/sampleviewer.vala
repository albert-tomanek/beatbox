namespace Beatbox
{
	[GtkTemplate (ui = "/com/github/albert-tomanek/beatbox/sampleviewer.ui")]
	public class SampleViewer : Gtk.Overlay
	{
		public Sample? sample { get; set; }

		double start;		// As a fraction of duration of the whole sample
		double duration;	// in seconds

		public double zoom { get; set; default = 0; }
		public double sec_pixels {
			get { return Math.exp2(zoom) * 100; }	// At zoom 0, 1s = 100px
		}

		int l_start {
			get {
				return int.max(0, (int) ((this.get_allocated_width() - (this.duration * sec_pixels)) / 2.0));
			}
		}

		int sample_width {	// Current width of the visualized sample in pixels (without padding)
			get {
				return this.sample == null ? 0 : (int) (this.sample.duration * this.sec_pixels / (double) Gst.SECOND);
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
			this.notify["sample"].connect(this.on_new_sample);
			this.notify["zoom"].connect(this.on_zoom_changed);
			this.size_allocate.connect(this.on_zoom_changed);

			this.sample_area.draw.connect_after(this.render_sample);
		}

		void on_new_sample()
		{
			this.start = 0;
			this.duration = 4;//((4 * Gst.SECOND) / (double) this.sample.duration).clamp(0, 1);

			this.sample.visu_updated.connect(this.sample_area.queue_draw);

			this.on_zoom_changed();	// Sample area needs to change length anyway
		}

		void on_zoom_changed()
		{
			this.sample_area.set_size_request(l_start + this.sample_width + l_start, -1);		// l_start is added for the empty padding at the start and end of the sample
			this.paned_l.set_position(l_start);
			this.paned_r.set_position((this.get_allocated_width() / 2) - l_start);

			this.scrollwindow.hadjustment.value = this.sample_width * this.start;
		}

		[GtkCallback]
		bool on_scroll(Gdk.EventScroll event)
		{
			if (event.get_source_device().input_source == Gdk.InputSource.MOUSE)	// Doesn't recognise my touchpad for some reason...
			{
				if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)
				{
					this.zoom = double.min(this.zoom - event.delta_y, 2);
				}
				else
				{
					this.scrollwindow.hadjustment.value += -event.delta_y * ((event.state & Gdk.ModifierType.SHIFT_MASK) != 0 ? 0.25 : 1) * 40;
					this.start = this.scrollwindow.hadjustment.value / (double) sample_width;
				}
			}

			return false;
		}

		public bool render_sample (Cairo.Context context)
		{
			if (this.sample != null)
			{
				set_context_rgb(context, TilePalette.WHITE);
				Sample.draw_amplitude(this.sample, context, l_start, 0, this.sample_width, this.sample_area.get_allocated_height());
			}

			return true;
		}
	}
}
