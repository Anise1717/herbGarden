package main
import "core:bufio"
import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:terminal"
import "herbGarden"
main :: proc() {
	herbGarden.enable_raw()
	herbGarden.enter_alt_screen()
	herbGarden.hide_cursor()
	
	_, window := herbGarden.size()

	defer herbGarden.show_cursor()
	defer herbGarden.leave_alt_screen()
	defer herbGarden.disable_raw()
	input_arena: virtual.Arena
	ani, _ := herbGarden.create_cells(window.column, window.row, 0, 0)
	key: herbGarden.Key
	if virtual.arena_init_static(&input_arena) != nil {panic("allocator error at line 13")}
	defer virtual.arena_free_all(&input_arena)
	input_allocator := virtual.arena_allocator(&input_arena)
	testcolor := herbGarden.color{255, 255, 255}
	herbGarden.set_bg_color(&ani, 30, 30, testcolor)
	herbGarden.write(&ani, 30, 30, "hello World")
	herbGarden.flush(&ani)
	for {
		key = herbGarden.keypress(os.stdin)
		fmt.print(key)
		switch k in key {
		case rune:
			if k == 'q' {
				return
			}

		case herbGarden.Special_Key:
			if .Ctrl in k.mods && k.code == .Right {
				fmt.println("ctrl+right — jump word")
			} else {
				fmt.printf("special: %v mods: %v\n\r", k.code, k.mods)
			}

		case os.Error:
			fmt.println("read error / EOF, exiting")
			return
		}
	}

}
