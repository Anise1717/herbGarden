package main
import "core:bufio"
import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:terminal"
import "herbGarden"
main :: proc() {
	herbGarden.init_window()

	defer herbGarden.disable_raw()
	input_arena: virtual.Arena
	key: herbGarden.Key
	if virtual.arena_init_static(&input_arena) != nil {panic("allocator error at line 13")}
	defer virtual.arena_free_all(&input_arena)
	input_allocator := virtual.arena_allocator(&input_arena)
	for {
		key = herbGarden.keypress(os.stdin)
		fmt.print(key)
		switch k in key {
		case rune:
			if k == 'q' {
				return
			}
			fmt.printf("char: %r\n\r", k)

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
