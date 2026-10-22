package main
import "core:bufio"
import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:sync"
import "core:sys/posix"
import "core:terminal"
import "herbGarden"

window_resized := false
SIGWINCH :: posix.Signal(28)
sigwinch_handle :: proc "c" (sig: posix.Signal) {
	sync.atomic_store(&window_resized, true)

}
main :: proc() {
	act: posix.sigaction_t
	act.sa_handler = sigwinch_handle
	posix.sigemptyset(&act.sa_mask)
	act.sa_flags = {}
	posix.sigaction(SIGWINCH, &act, nil)
	herbGarden.enable_raw()
	herbGarden.enter_alt_screen()
	//	herbGarden.hide_cursor()

	_, window := herbGarden.size()

	//	defer herbGarden.show_cursor()
	defer herbGarden.leave_alt_screen()
	defer herbGarden.disable_raw()
	input_arena: virtual.Arena
	ani, _ := herbGarden.create_cells(window.row / 2, window.column / 2, 0, 0)
	ani2, _ := herbGarden.create_cells(window.row / 2, window.column / 2, 0, window.column / 2)
	key: herbGarden.Key
	if virtual.arena_init_static(&input_arena) != nil {panic("allocator error at line 13")}
	defer virtual.arena_free_all(&input_arena)
	input_allocator := virtual.arena_allocator(&input_arena)
	testcolor := herbGarden.color{255, 255, 255}
	herbGarden.set_color(&ani, 30, 30, testcolor, .BG)
	fmt.printf("col:%d,row:%d", window.column, window.row)
	herbGarden.write(&ani, 1, 1, "hello World")
	herbGarden.write(&ani2, 30, 30, "hello World")
	herbGarden.draw_border(&ani)
	herbGarden.draw_border(&ani2)
	herbGarden.flush(&ani)
	herbGarden.flush(&ani2)
	cursor_x, cursor_y: u16 = 0, 0
	draw_status(cursor_x, cursor_y, window.row)

	for {
		if sync.atomic_exchange(&window_resized, false) {
			_, window = herbGarden.size()
			herbGarden.resize_cells(&ani, window.row / 2, window.column / 2, 0, 0)
			herbGarden.resize_cells(&ani2, window.row / 2, window.column / 2, 0, window.column / 2)
		}
		key = herbGarden.keypress(os.stdin)
		switch k in key {
		case rune:
			if k == 'q' {
				return
			}

		case herbGarden.Special_Key:
			#partial switch k.code {
			case .Left:
				cursor_x -= 1
			case .Right:
				cursor_x += 1
			case .Up:
				cursor_y -= 1
			case .Down:
				cursor_y += 1
			}
			draw_status(cursor_x, cursor_y, window.row)

		case os.Error:
			if k==nil {
				continue
			};
			return
		}
	}

}
draw_status :: proc(x, y, rows: u16) {
	fmt.printf("\x1b[%d;1H\x1b[2K x: %3d  y: %3d \x1b[%d;%dH", rows, x, y, y + 1, x + 1)
}
