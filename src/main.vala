/*
* Copyright (c) {{yearrange}} albert ()
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: albert <>
*/
using Granite;
using Granite.Widgets;
using Gtk;

namespace Beatbox {
    public class Application : Granite.Application
	{
        public Application () {
            Object (
                application_id: "com.github.albert-tomanek.beatbox",
                flags: ApplicationFlags.FLAGS_NONE
            );
        }

        protected override void activate () {
            var window = new MainWindow (this);
            window.show_all ();
        }

        public static int main (string[] args) {
            Gst.init(ref args);
            GES.init();

            var app = new Beatbox.Application ();
            return app.run (args);
        }
    }

	[GtkTemplate (ui = "/com/github/albert-tomanek/beatbox/main.ui")]
	public class MainWindow : Gtk.ApplicationWindow
	{
		[GtkChild] Gtk.Grid tile_grid;
		[GtkChild] Gtk.Label msg_label;
		[GtkChild] Gtk.SpinButton bpm_entry;
		[GtkChild] Gtk.ToggleButton play_button;

		public float bpm { get {return (float) this.bpm_entry.value; } }
		public Gst.ClockTime beat_duration { get { return (int64) ((60 * Gst.SECOND) / this.bpm); } }

		public MainWindow(Gtk.Application app)
		{
			Object(application: app);
			this.load_style();

			this.get_settings().get_default().gtk_application_prefer_dark_theme = true;

			this.init_audio();

			/* Fill grid of tile spaces */
			for (var col = 0; col < 4; col++) {
				for (var row = 0; row < 4; row++) {
					var host = new TileHost();
					host.bar_no = col;
					host.track_no = row;
					this.tile_grid.attach(host, col, row);
					host.uri_dropped.connect((host, uri) => {
						host.tile = new LoopTile(this, uri);
					});
				}
			}

			this.tile_grid.show_all();

			(this.tile_grid.get_child_at(0, 1) as TileHost).tile = new DummyTile(this);
			(this.tile_grid.get_child_at(2, 0) as TileHost).tile = new DummyTile(this);
		}

		private void load_style()
		{
			var css_provider = new Gtk.CssProvider();
			css_provider.load_from_resource("/com/github/albert-tomanek/beatbox/style.css");
			Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
		}

		/* UI callbacks */
		[GtkCallback]
		internal void on_metronome_toggled(Gtk.ToggleButton tog)
		{
		}

		[GtkCallback]
		internal void on_play_toggled(Gtk.ToggleButton tog)
		{
			if (tog.active)
			{
				this.timeline.commit();
				this.pipeline.set_state(Gst.State.PLAYING);
			}
			else
			{
				this.pipeline.set_state(Gst.State.READY);
			}
		}

		/* UI helpers */

		internal void foreach_tilehost(Gtk.Callback cb)
		{
			this.tile_grid.foreach(cb);
		}

		/* Audio playback */
        internal GES.Pipeline pipeline;  // Gstreamer pipeline
		internal GES.Timeline timeline;  // Every time the user schedules a tile to start playing, it's added as a clip to the timeline.
		internal GES.Track    audio_track;

        private void init_audio()	// https://github.com/GStreamer/gst-editing-services/blob/master/examples/python/simple.py
        {
            this.timeline = new GES.Timeline();

			this.audio_track = new GES.AudioTrack();
			this.timeline.add_track(this.audio_track);
			// this.audio_track.update_restriction_caps(Gst.Caps.from_string("audio/x-raw, format=F32, channels=2, rate=44100"));

            this.pipeline = new GES.Pipeline();
            this.pipeline.set_timeline(this.timeline);
			this.pipeline.get_bus().add_watch(GLib.Priority.DEFAULT, this.on_pipeline_message);

//			Timeout.add(100, () => { this.log(@"$(this.timeline.get_base_time())\t$(this.timeline.get_clock().get_time() / Gst.MSECOND)"); return true; });
        }

		// bool is_correctionary_seek = false;
		// if (!is_correctionary_seek)
		// {
		// 	is_correctionary_seek = true;
		// 	print("seeking...\n");
		// 	this.timeline.seek_simple(Gst.Format.TIME, Gst.SeekFlags.FLUSH | Gst.SeekFlags.ACCURATE, (int64) this.timeline.get_base_time());
		// }
		// else
		// {
		// 	is_correctionary_seek = false;
		// }

		bool on_pipeline_message(Gst.Bus bus, Gst.Message msg)
		{
			// print(msg.type.to_string()+"\n");
			switch (msg.type) {
				case Gst.MessageType.RESET_TIME:
				{
					print(@"$(this.timeline.get_base_time())\n");
					break;
				}
				case Gst.MessageType.EOS:
				{
					this.play_button.set_active(false);
					break;
				}
				case Gst.MessageType.ERROR:
				{
					Error error; string dbg;
					msg.parse_error(out error, out dbg);
					this.log(error.message + "\n" + dbg);
					break;
				}
				case Gst.MessageType.ELEMENT:
				{
					//msg.parse_
					print(@" `-> $(msg.get_structure().get_name())\n");
					break;
				}
				case Gst.MessageType.DURATION_CHANGED:
				{
					print(@" `-> $(this.timeline.duration / Gst.MSECOND)\n");
					break;
				}
				case Gst.MessageType.STATE_CHANGED:
				{
					Gst.State old_state;
					Gst.State new_state;
					Gst.State pending_state;

					msg.parse_state_changed (out old_state, out new_state, out pending_state);

					break;
				}
			}

			return true;
		}

		LivePlayback live;

		/* Misc. */

		internal void log(string text)
		{
			this.msg_label.label = text;
		}
	}

	class LivePlayback
	{
	}
}

internal Gst.ClockTime get_running_time(Gst.Element element)
{
	return element.get_clock().get_time() - element.get_start_time();
}
