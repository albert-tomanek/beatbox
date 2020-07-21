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

	delegate void GstElementFunc(Gst.Element element);

	internal uint add_state_change_cb(Gst.Element element, Gst.State from, Gst.State to, GstElementFunc cb)
	{
		var id = element.bus.add_watch(Priority.DEFAULT, (bus, msg) => {
			if (msg.type == Gst.MessageType.STATE_CHANGED)
			{
				Gst.State old, @new;
				msg.parse_state_changed(out old, out @new, null);

				if (old == from && @new == to)
					cb(element);
			}

			return true;
		});

		return id;
	}
}
