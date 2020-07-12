namespace Beatbox
{
	public class SampleCache
	{
		public ByteArray array;

		public float[] visu_l = new float[512];
		public float[] visu_r = new float[512];

		public signal void visu_updated();

		public SampleCache.copy(SampleCache src)
		{
			this.visu_l = src.visu_l;	// should make a copy of all these
			this.visu_r = src.visu_r;
			this.array  = new ByteArray.sized(src.array.len);
			this.array.data = src.array.data;
		}
	}

	class CacheSrc : Gst.App.Src
	{
	}

	class CacheSink : Gst.App.Sink
	{
	}

	public class SampleCacher : Object
	{
		public SampleCache out_cache { get; set; }
		public LoopTile in_tile { get; set; }

		Gst.Pipeline pipeline;
		Gst.Element  uridecodebin;
		Gst.Element  audioconvert;
		Gst.Element  level;
		Gst.Element  fakesink;

		uint visu_idx;

		construct
		{
			this.notify["out-cache"].connect(() => {
				level.set("interval", in_tile.duration / out_cache.visu_l.length);
			});
			this.notify["in-tile"].connect(() => {
				uridecodebin.set("uri", in_tile.sample.uri);
			});

			/* Create elements */
			pipeline = new Gst.Pipeline(null);
			uridecodebin  = Gst.ElementFactory.make ("uridecodebin", null);
			audioconvert  = Gst.ElementFactory.make ("audioconvert", null);
			level         = Gst.ElementFactory.make ("level", null);
			fakesink      = Gst.ElementFactory.make ("fakesink", null);

			/* Link elements */
			pipeline.add_many(uridecodebin, audioconvert, level, fakesink);
			audioconvert.link_many(level, fakesink);	// ?

			uridecodebin.pad_added.connect((pad) => { pad.link(audioconvert.get_static_pad("sink")); });
		}

		uint update_interval;

		public async void run(uint update_interval = 8)		// yield and update every visu samples
		{message("RUN!\n");
			Idle.add(run.callback);
			yield;

			this.update_interval = update_interval;
			visu_idx = 0;

			/* Seeking will fail unless uridecodebin has had an opportunity to read metadata about the URI that it's playing.
			 * This doesn't happen until the element is set to PLAYING.
			 * Hence, we need to play it first and wait until the PLAYING state has propagated through the whole pipeline.	*/

			pipeline.set_state(Gst.State.PLAYING);

			wait_for_state_change(pipeline, Gst.State.PAUSED, Gst.State.PLAYING, 100 * Gst.MSECOND);

			/* Seek to the segment that the tile is playing. This will pause the pipeline briefly.
			 * Only once it resumes playing do we register our amplitude-saving callback.
			 * If we registered it earlier, it would save the garbae created when ran the pipeline the first time and overrun the visu buffer.	*/

			pipeline.seek(
				1.0, Gst.Format.TIME, Gst.SeekFlags.FLUSH | Gst.SeekFlags.SEGMENT | Gst.SeekFlags.ACCURATE,
				Gst.SeekType.SET, (int64) in_tile.start_tm,
				Gst.SeekType.SET, (int64) (in_tile.start_tm + in_tile.duration)
			);

			wait_for_state_change(pipeline, Gst.State.PAUSED, Gst.State.PLAYING, 100 * Gst.MSECOND);

			var con_id = pipeline.bus.message.connect(on_bus_message);	// <- yields inside on_bus_message after reading every n samples

			/* Wait till the segment has been processed */

			pipeline.bus.poll(Gst.MessageType.SEGMENT_DONE, 700 * Gst.MSECOND);
			message("Segment DONE\n");
			pipeline.bus.disconnect(con_id);
			stdout.printf("%u\t%llu\n", visu_idx, pipeline.get_clock().get_time());
			pipeline.set_state(Gst.State.READY);	// Keep the file open. We may be asked to cache a similar clip soon. (especially if they're scrolling.)
			return;
		}

		private void on_bus_message(Gst.Message msg)
		{
			if (msg.type == Gst.MessageType.ELEMENT && msg.get_structure() != null)
			{
				if (msg.get_structure().get_name() == "level" && visu_idx < this.out_cache.visu_l.length)	// Some elements like mpegaudioparse seem to feed a few buffers after the segment's finished, so we need to ignore those.
				{
					GLib.ValueArray channels;
					msg.get_structure().get("rms", typeof(GLib.ValueArray), out channels);

					float decibels = (float) channels.get_nth(0).get_double();
					float loudness = Math.exp10f(decibels/20f);		// Reverse the operation [here]. Values should be [0, 1] but tend to be [0, 0.25].  https://github.com/GStreamer/gst-plugins-good/blob/master/gst/level/gstlevel.c#L701
//					float loudness = (decibels + 60) / 60f;

					out_cache.visu_l[visu_idx] = out_cache.visu_r[visu_idx] = loudness.clamp(0, 1);		// TODO: Make both channels discrete

					stdout.printf("%u\t%llu\n", visu_idx, pipeline.get_clock().get_time());
					if (visu_idx % update_interval == 0)
					{
						out_cache.visu_updated();
						yield;
					}

					visu_idx++;
				}
			}
		}

	}
}
