#+ feature dynamic-literals
package main
import "core:bufio"
import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:slice"
import "core:sync"
import "core:sys/posix"
import "core:terminal"
import "seeds"
import "sprouts"


main :: proc() {

	app := sprouts.App{}
	sprouts.app_init(&app)
	
	seeds.enter_alt_screen()
	sprouts.app_register(&app, sprouts.Text, sprouts.text_destroy)
	tb1 := sprouts.make_text_box(&app, .5, .5, .33, .33)
	sprouts.win_resize(&app)
	sprouts.write_text(sprouts.app_get(&app, tb1, sprouts.Text), 2, 2, "foo")
	sprouts.draw(&app)


	for {
		sprouts.win_resize(&app)

		sprouts.draw(&app)
		key := seeds.keypress(os.stdin)
		if r, ok := key.(rune); ok && r == 'q' {
			seeds.disable_raw()
			break
		}
	}


}
