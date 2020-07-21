[CCode (cheader_filename = "gst/gst.h", cprefix = "FIX_GST_", lower_case_cprefix = "fix_gst_")]
namespace _Gst
{
	[SimpleType]
	[CCode(type_id = "G_TYPE_UINT64")]	// <- Without this line, Vala thinks the type is BOXED and gives an error when using it as a property in a class that inherits from Object. https://gist.github.com/albert-tomanek/f6dcf4af0aadbc4792b1af7e4e30531b
	public struct ClockTime : uint64
	{
	}

	namespace StaticCaps
	{
		// [CCode(cname = "GST_STATIC_CAPS_ANY")]
		// extern const Gst.StaticCaps ANY;
		// [CCode(cname = "GST_STATIC_CAPS_NONE")]		// <- These don't work cause they're macros for struct definitions
		// extern const Gst.StaticCaps NONE;

		const Gst.StaticCaps ANY  = { null, "ANY" };
		const Gst.StaticCaps NONE = { null, "NONE" };
	}
}
