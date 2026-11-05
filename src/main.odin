package main
import "core:bufio"
import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:sync"
import "core:sys/posix"
import "core:terminal"
import "seeds"

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
	seeds.enable_raw()
	seeds.enter_alt_screen()
	//	seeds.hide_cursor()

	_, window := seeds.size()

	//	defer seeds.show_cursor()
	defer seeds.leave_alt_screen()
	defer seeds.disable_raw()
	input_arena: virtual.Arena
	ani, _ := seeds.create_cells(window.row / 2, window.column / 2, 0, 0)
	ani2, _ := seeds.create_cells(window.row / 2, window.column / 2, 0, window.column / 2)
	key: seeds.Key
	if virtual.arena_init_static(&input_arena) != nil {panic("allocator error at line 13")}
	defer virtual.arena_free_all(&input_arena)
	input_allocator := virtual.arena_allocator(&input_arena)
	testcolor := seeds.color{0, 255, 0}
	seeds.set_color(&ani, 11, 1, testcolor, .FG)
	fmt.printf("col:%d,row:%d", window.column, window.row)
	seeds.write(&ani, 1, 1, "hello World")
	seeds.write(&ani2, 30, 30, "hello World")
	seeds.draw_border(&ani)
	seeds.draw_border(&ani2)
	seeds.flush(&ani)
	seeds.flush(&ani2)
	cursor_x, cursor_y, _ := seeds.get_cursor_position()
	draw_status(cursor_x, cursor_y, window.row)
	toggle := true

	for {
		if sync.atomic_exchange(&window_resized, false) {
			_, window = seeds.size()
			seeds.resize_cells(&ani, window.row / 2, window.column / 2, 0, 0)
			seeds.resize_cells(&ani2, window.row / 2, window.column / 2, 0, window.column / 2)
		}
		key = seeds.keypress(os.stdin)
		switch k in key {
		case rune:
			if k == 'q' {
				return
			}
			if k == 'c' {
				seeds.clear_buffer(&ani)
			}
			if k == 's' {
				if toggle {
					seeds.fill(&ani, testcolor)
				} else {
					seeds.fill(&ani, {255, 0, 0})
				}
				toggle = !toggle
			}


		case seeds.Special_Key:
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
			if k == nil {
				continue
			}
			return
		}
		seeds.flush(&ani)
		seeds.flush(&ani2)
	}

}
draw_status :: proc(x, y, rows: u16) {
	fmt.printf("\x1b[%d;1H\x1b[2K x: %3d  y: %3d \x1b[%d;%dH", rows, x, y, y + 1, x + 1)
}
