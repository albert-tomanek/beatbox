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
            var app = new Beatbox.Application ();
            return app.run (args);
        }
    }

	[GtkTemplate (ui = "/com/github/albert-tomanek/beatbox/main.ui")]
	class MainWindow : Gtk.ApplicationWindow
	{
		[GtkChild] Gtk.Grid tile_grid;

		public MainWindow(Gtk.Application app)
		{
			Object(application: app);
			this.load_style();

			for (var col = 0; col < 3; col++) {
				for (var row = 0; row < 3; row++) {
					var host = new TileHost();
					this.tile_grid.attach(host, row, col);
					host.show();
				}
			}

			(this.tile_grid.get_child_at(0, 1) as TileHost).tile = new DummyTile();
			(this.tile_grid.get_child_at(2, 0) as TileHost).tile = new DummyTile();
		}

		private void load_style()
		{
			var css_provider = new Gtk.CssProvider();
			css_provider.load_from_resource("/com/github/albert-tomanek/beatbox/style.css");
			Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
		}
	}
}
