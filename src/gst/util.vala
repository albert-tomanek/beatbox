namespace Beatbox
{
	internal Gst.ClockTime get_running_time(Gst.Element element)
	{
		return element.get_clock().get_time() - element.get_start_time();
	}

	internal void wait_for_state_change(Gst.Element element, Gst.State from, Gst.State to, Gst.ClockTime timeout = Gst.CLOCK_TIME_NONE)
	{
		Gst.State  old = Gst.State.NULL;
		Gst.State @new = Gst.State.NULL;

		do
		{
			var msg = element.bus.poll(Gst.MessageType.STATE_CHANGED, timeout);
			msg.parse_state_changed(out old, out @new, null);
			print(@"$(element.name): $(old) -> $(@new)\n");
		} while (!(old == from && @new == to));
	}
}
