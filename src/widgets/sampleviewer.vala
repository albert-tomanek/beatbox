namespace Beatbox
{
	[GtkTemplate (ui = "/com/github/albert-tomanek/beatbox/sampleviewer.ui")]
	public class SampleViewer : Gtk.Overlay
	{
		public Sample sample { get; set; }

		double start;
		double duration;

		public float zoom { get; set; default = 1.0f; }	// At zoom 1, 1s = 100px

		double l_start {
			get {
				return 0;
			}
		}

		/* Child widgets */
		[GtkChild] Gtk.DrawingArea sample_area;
		[GtkChild] Gtk.ScrolledWindow scrollwindow;

		[GtkChild] Gtk.DrawingArea empty_l;
		[GtkChild] Gtk.DrawingArea empty_r;
		[GtkChild] Gtk.Paned paned_l;
		[GtkChild] Gtk.Paned paned_r;

		[GtkChild] Gtk.Adjustment hscroll_adjustment;

		construct {
			this.empty_l.add_events(Gdk.EventMask.ALL_EVENTS_MASK);
			this.empty_r.add_events(Gdk.EventMask.ALL_EVENTS_MASK);
			this.empty_l.scroll_event.connect(this.on_scroll);
			this.empty_r.scroll_event.connect(this.on_scroll);

			this.notify["sample"].connect(this.on_new_sample);
			this.notify["zoom"].connect(this.on_zoom_changed);

			this.sample_area.draw.connect_after(this.render_sample);
		}

		void on_new_sample()
		{
			this.start = 0;
			this.duration = ((4 * Gst.SECOND) / (double) this.sample.duration).clamp(0, 1);

			this.sample.visu_updated.connect(this.sample_area.queue_draw);

			this.on_zoom_changed();	// Sample area needs to change length anyway
		}

		void on_zoom_changed()
		{
			this.sample_area.set_size_request((int) (this.sample.duration / (double) Gst.SECOND) * 100, -1);
		}

		bool on_scroll(Gtk.Widget w, Gdk.EventScroll event)
		{print(@"$(this.scrollwindow.hadjustment.lower) < $(this.scrollwindow.hadjustment.value) < $(this.scrollwindow.hadjustment.upper)\t (w=$(this.sample_area.get_allocated_width()))\n");
			if (event.get_source_device().input_source == Gdk.InputSource.MOUSE)	// Doesn't recognise my touchpad for some reason...
			{
				if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)
				{
				}
				else
				{
					this.scrollwindow.hadjustment.value += event.delta_y * ((event.state & Gdk.ModifierType.SHIFT_MASK) != 0 ? 0.1 : 1) * (double) this.sample_area.get_allocated_width() / 512.0;
				}
			}

			return false;
		}

		public bool render_sample (Cairo.Context context)
		{
			set_context_rgb(context, TilePalette.WHITE);
			Sample.draw_amplitude(this.sample, context, 0, 0, this.sample_area.get_allocated_width(), this.sample_area.get_allocated_height());

			return true;
		}

		// internal override void size_allocate(Gtk.Allocation alloc)
		// {
		// 	this.refresh_panes();
		// }

		protected void refresh_panes()
		{

		}
	}
}
