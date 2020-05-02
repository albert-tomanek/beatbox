// This is a big fat botch to get around the fact that the Gst.Audio.Filter class in the VAPI is missing the `gst_audio_filter_class_add_pad_templates` class method that exists in C.
// So, we create our own wrapper for the class that has it included. Thanks: https://github.com/gandalfn/hottoe/blame/485fa030c83186e84d61c0a26393373fe3302a3f/vapi/gstreamer-audio-1.0.vapi#L327

[CCode (cname = "GstAudioFilter", cheader_filename = "mygstaudiofilter.h", type_id = "gst_audio_filter_get_type ()")]
public abstract class MyGstAudioFilter : Gst.Base.Transform {
	public weak Gst.Audio.Info info;

	[CCode (has_construct_function = false)]
	protected MyGstAudioFilter ();

	[NoWrapper]
	public virtual bool setup (Gst.Audio.Info info);

	/* MISSING from official GstAudio 1.0 vapi */
	[CCode (cname = "gst_audio_filter_class_add_pad_templates")]
	public class void add_pad_templates(Gst.Caps caps);
}
