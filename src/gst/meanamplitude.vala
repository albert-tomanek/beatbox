using Math;

// https://web.archive.org/web/20150424140513/http://www.majorsilence.com/pygtk_audio_and_video_playback_gstreamer
class MeanAmplitude : MyGstAudioFilter
{
	public uint window_len;

	private uint sample_no;
	private float l_avg;
	private float r_avg;

	private Gst.Audio.Info _info;	// There's a bug in valac if we use the inherited `info`

	public MeanAmplitude(uint? window_len = null)
	{
		this.window_len = window_len;
		this.set_in_place(true);
	}

	static construct {
		Gst.Caps caps = Gst.Caps.from_string("audio/x-raw,format=F32,channels=[1,2],layout=interleaved");
        add_pad_templates (caps);
	}

	public override bool setup (Gst.Audio.Info info)
	{
		this._info = info.copy();
		return true;
	}

	public override Gst.FlowReturn transform_ip(Gst.Buffer buf)
	{
		unowned uint8[] sample_data;
		size_t data_sz = buf.extract(0, out sample_data);

		var samples = (float[]) sample_data;

		for (uint i = 0; i < data_sz / 4; i++)
		{
			if (this.sample_no == this.window_len)
				this.emit_avg();

			if (sample_no % 2 == 1 && this._info.channels != 1)
			{
				r_avg = (r_avg * sample_no + fabsf(samples[i])) / (sample_no + 1);
			}
			else
			{
				l_avg = (l_avg * sample_no + fabsf(samples[i])) / (sample_no + 1);

				this.sample_no++;	// Increments on every other sample if data is stereo.
			}
		}

		return Gst.FlowReturn.OK;
	}

	private void emit_avg()
	{
		if (this._info.channels == 1)
			r_avg = l_avg;

		Gst.Structure struc = new Gst.Structure("mean-amplitude", "l_avg", l_avg, "r_avg", r_avg);
		var msg = new Gst.Message.custom(Gst.MessageType.ELEMENT, this, (owned) struc);
		this.post_message(msg);
	}
}

// audio/x-raw,format=S16LE,channels=2,layout=interleaved
// if (this._info.finfo.width == )
