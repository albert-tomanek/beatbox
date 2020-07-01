namespace _Gst
{
	[SimpleType]
	[CCode(type_id = "G_TYPE_UINT64")]	// <- Without this line, Vala thinks the type is BOXED and gives an error when using it as a property in a class that inherits from Object. https://gist.github.com/albert-tomanek/f6dcf4af0aadbc4792b1af7e4e30531b
	public struct ClockTime : uint64
	{
	}
}
