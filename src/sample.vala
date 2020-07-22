namespace Beatbox
{
	public class Sample : Object
	{
		/* This contains metadata (and sometimes caches) about a sample.	*
		 * It can be referenced by multiple loop tiles.						*/

		public string uri { get; construct; }

		internal float[] visu_l;
		internal float[] visu_r;
		internal signal void visu_updated();

		public _Gst.ClockTime duration { get; private construct; }

		public Sample(string uri)
		{
			Object(uri: uri);
		}

		construct {
			this.duration = read_duration(this.uri);

			this.visu_l = new float[this.duration * 48 / Gst.SECOND];	// 48 samples for amplitude visualisation / second
			this.visu_r = new float[this.duration * 48 / Gst.SECOND];
			this.load_repr.begin();
		}

		private async void load_repr(uint update_interval = 64)	// Cancellable? c	// update_interval: trigger visu_updated every n samples
		{
			uint visu_idx = 0;

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
			level.set("interval", this.duration / this.visu_l.length);

			Idle.add(load_repr.callback);
			yield;

			pipeline.set_state(Gst.State.PLAYING);
			pipeline.get_bus().message.connect((msg) => {
				if (msg.type == Gst.MessageType.ERROR)
				{
					Error error;
					string dbg;
					msg.parse_error(out  error, out dbg);
					printerr(error.message + "\n" + dbg + "\n");
				}
				if (msg.type == Gst.MessageType.ELEMENT && msg.get_structure() != null)
				{
					if (msg.get_structure().get_name() == "level" && visu_idx < this.visu_l.length)
					{
						GLib.ValueArray channels;
						msg.get_structure().get("rms", typeof(GLib.ValueArray), out channels);

						float decibels = (float) channels.get_nth(0).get_double();
						float loudness = Math.exp10f(decibels/20f);	// Reverse the operation [here]. Values should be [0, 1] but tend to be [0, 0.25].  https://github.com/GStreamer/gst-plugins-good/blob/master/gst/level/gstlevel.c#L701
//						float loudness = (decibels + 60) / 60f;

						this.visu_l[visu_idx] = this.visu_r[visu_idx] = loudness.clamp(0, 1);		// TODO: Make both channels discrete

						visu_idx++;

						if (visu_idx % update_interval == 0)
						{
							this.visu_updated();
							yield;
						}
					}
				}
			});

			/* Wait for the stream to end */
			pipeline.get_bus().poll(Gst.MessageType.EOS, Gst.CLOCK_TIME_NONE);
			pipeline.set_state(Gst.State.NULL);
		}

		private static Gst.ClockTime read_duration(string uri)
		{
			var discoverer = new Gst.PbUtils.Discoverer(500 * Gst.MSECOND);
			var info = discoverer.discover_uri(uri);

			return info.get_duration();
		}

		internal static void draw_amplitude(float[] visu_l, float[] visu_r, Cairo.Context context, int x, int y, int width, int height, int _visu_offset = 0)
		{
			assert(visu_l.length == visu_r.length);

			var half_height = (height / 2);
			var baseline_y  = y + half_height;
			var x_step = (float) width / (visu_l.length  - 1);
			int i_step = (int) (x_step > 1 ? 1 : 1 / x_step);		// If there's more than one aplitude pt per pixel, increment the index by more than 1 each time to skip some.
			int i = i_step - (_visu_offset % i_step);		// Usually 0. If we draw only every nth enrty in the array, this ensures that we skip the same values each time and hence prevents the flickering that would otherwise happen while scrolling.

			context.move_to(x + 0, baseline_y);

			/* Draw top half, left channel */
			for (; i < visu_l.length; i += i_step)	// <- will usually be += 1 unless x_step is tiny.
			{
				float amplitude = visu_l[i];
				context.line_to(
					x + i * x_step,
					baseline_y - (amplitude * half_height)
				);
			}

			/* Draw bottom half, right channel */
			for (; i >= 0 ; i -= i_step)
			{
				float amplitude = visu_r[i];
				context.line_to(
					x + i * x_step,
					baseline_y + (amplitude * half_height)
				);
			}

			context.close_path();
			context.fill();
		}
	}
}
