namespace Beatbox
{
	class Sample : Object
	{
		public string uri { get; construct; }

		internal float[] visu_l = new float[512];
		internal float[] visu_r = new float[512];
		internal signal void visu_updated();

		public Sample(string uri)
		{
			Object(uri: uri);
		}

		construct {
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
			level.set("interval", this.get_duration() / 512);

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

		private Gst.ClockTime get_duration()
		{
			var discoverer = new Gst.PbUtils.Discoverer(0);
			var info = discoverer.discover_uri(this.uri);

			return info.get_duration();
		}
	}

	class ClipDef
	{
		Sample sample;

		double start;		// These are fractions of the duration of the source sample.
		double duration;
	}
}
