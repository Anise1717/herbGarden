#+ feature dynamic-literals
package main
import "core:fmt"
import "core:os"
import "core:strings"
import "seeds"
import "sprouts"


main :: proc() {

	app := sprouts.App{}
	sprouts.app_init(&app)

	seeds.enter_alt_screen()
	sprouts.register_text_box(&app)
	tb1 := sprouts.make_text_box(&app, 0, 0, 1, 1)
	sprouts.win_resize(&app)
	sprouts.app_run_draw(&app)


	// sprouts.write_text(&app,tb1, 2, 2, "foo")


	grad(&app, tb1)
	sprouts.draw_buffer_diff(&app)

	for {
		sprouts.win_resize(&app)


		grad(&app, tb1)
		sprouts.app_run_draw(&app)
		sprouts.draw_buffer_diff(&app)
		key := seeds.keypress(os.stdin)
		if r, ok := key.(rune); ok && r == 'q' {
			seeds.disable_raw()
			break
		}
	}


}
grad :: proc(app: ^sprouts.App, box: sprouts.WidgetId) {
	tb := sprouts.app_get(app, box, sprouts.Text)
	area := sprouts.app_get(app, box, sprouts.Area)
	bg := sprouts.app_get(app, box, sprouts.Bg_Color)
	r: u8 = 0
	g: u8 = 0
	b: u8 = 0
	n := area.length * area.height

	for row in 0 ..< area.height {
		for col in 0 ..< area.length {

			idx, _ := sprouts.get_idx(area, row, col)
			bg.color[idx].r = u8(col * 255 / max(area.length - 1, 1))
			bg.color[idx].g = u8(row * 255 / max(area.height - 1, 1))
			bg.color[idx].b = 128
		}
	}
}
