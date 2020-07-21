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
        [GtkChild] Gtk.Image play_button_image;
		// [GtkChild] Dazzle.DockRevealer sample_revealer;
        [GtkChild] Dazzle.DockBin dock_bin;
        [GtkChild] Gtk.Box sv_box;
		internal SampleViewer sample_viewer;

		public float bpm { get {return (float) this.bpm_entry.value; } }
		public _Gst.ClockTime beat_duration { get { return (int64) ((60 * Gst.SECOND) / this.bpm); } }

		public MainWindow(Gtk.Application app)
		{
			Object(application: app);
			this.load_style();

			this.get_settings().get_default().gtk_application_prefer_dark_theme = true;

			this.init_audio();
			this.init_ui();
		}

		private void init_ui()
		{
			this.sample_viewer = new SampleViewer();
			this.sv_box.add(this.sample_viewer);
            this.dock_bin.bottom_visible = true;

			/* Fill grid of tile spaces */
			for (var col = 0; col < 4; col++) {
				for (var row = 0; row < 4; row++) {
					var host = new TileHost(this);
					host.bar_no = col;
					host.track_no = row;
					this.tile_grid.attach(host, col, row);
					host.uri_dropped.connect((host, uri) => {
						host.tile = new LoopTile(this, uri);
					});
				}
			}

			this.tile_grid.show_all();
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
                this.play_button_image.set_from_icon_name("media-playback-stop-symbolic", Gtk.IconSize.BUTTON);
			}
			else
			{
				this.pipeline.set_state(Gst.State.READY);
                this.play_button_image.set_from_icon_name("media-playback-start-symbolic", Gtk.IconSize.BUTTON);
			}
		}

		[GtkCallback]
		internal void toggle_show_sample()
		{
            this.dock_bin.bottom_visible = !this.dock_bin.bottom_visible;
		}

        internal void on_dupl_tile(Tile tile)
        {
            var copy = new LoopTile.copy(tile as LoopTile);
            (this.tile_grid.get_child_at((int) tile.host.bar_no + 1, (int) tile.host.track_no) as TileHost).tile = copy;
        }

		/* UI helpers */

		internal delegate void TileHostCallback(TileHost host);
		public   delegate void TileCallback    (Tile tile);

		internal void foreach_tilehost(TileHostCallback callback)
		{
			this.tile_grid.foreach((widget) => {
				callback(widget as TileHost);
			});
		}

		public void foreach_tile(TileCallback callback)
		{
			this.foreach_tilehost((host) => {
				if (host.tile != null)
					callback(host.tile);
			});
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

		bool on_pipeline_message(Gst.Bus bus, Gst.Message msg)
		{
			// print(msg.type.to_string()+"");
			switch (msg.type) {
				// case Gst.MessageType.RESET_TIME:
				// {
				// 	print(@"\n `-> $(this.timeline.get_base_time())");
				// 	break;
				// }
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
				// case Gst.MessageType.ELEMENT:
				// {
				// 	//msg.parse_
				// 	print(@"\n `-> $(msg.get_structure().get_name())");
				// 	break;
				// }
				// case Gst.MessageType.DURATION_CHANGED:
				// {
				// 	print(@"\n `-> $(this.timeline.duration / Gst.MSECOND)");
				// 	break;
				// }
				// case Gst.MessageType.STATE_CHANGED:
				// {
				// 	Gst.State old_state;
				// 	Gst.State new_state;
				// 	Gst.State pending_state;
                //
				// 	msg.parse_state_changed (out old_state, out new_state, out pending_state);
				// 	print(@"\t$(old_state) => $(new_state)");
				// 	break;
				// }
			}

			// print("\n");
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
