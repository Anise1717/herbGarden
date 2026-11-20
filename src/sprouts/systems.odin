package sprouts
import "../seeds"
import "base:intrinsics"
import "core:fmt"

write_text :: proc(box: ^Text, row: int, col: int, content: string) -> bool {
	idx, ok := get_idx(box, row, col)
	if !ok {

		return false
	}
	for char in content {
		box.text[idx] = char
		idx += 1
	}
	return true

}


get_idx :: #force_inline proc(box: ^Text, row: int, col: int) -> (int, bool) {
	if row > box.height || col > box.length {
		return -1, false
	}
	return row * box.length + col, true
}

win_resize :: proc(app: ^App) {
	flag := intrinsics.atomic_exchange(&g_window_resized, false)
	if !flag {
		return
	}

	ok, _ := seeds.size()
	if !ok {
		return
	}

	fmt.print("\x1b[2J\x1b[H")
	query := make_signature(Position, Text, Size_Scale, Postion_scale)
	archs := app_matching_archetypes(app, query[:])
	for arch in archs {
		sscale := archetype_data(arch, Size_Scale)
		pscale := archetype_data(arch, Postion_scale)
		text := archetype_data(arch, Text)
		pos := archetype_data(arch, Position)

		for i in 0 ..< len(sscale) {
			text[i].height = int(f32(seeds.ws.row) * sscale[i].height)
			text[i].length = int(f32(seeds.ws.column) * sscale[i].width)
			resize(&text[i].text, text[i].length * text[i].height)
		}
		for i in 0 ..< len(pscale) {
			pos[i].y = int(f32(seeds.ws.row) * pscale[i].y)
			pos[i].x = int(f32(seeds.ws.column) * pscale[i].x)
		}
	}
}
draw :: proc(app: ^App) {
	query := make_signature(Position, Text, Size_Scale, Postion_scale)
	archs := app_matching_archetypes(app, query[:])
	for arch in archs {
		text := archetype_data(arch, Text)
		pos := archetype_data(arch, Position)
		for i in 0 ..< len(pos) {
			t := text[i]
			if len(t.text) < t.length * t.height { continue }

			for row in 0 ..< t.height {
				fmt.printf("\e[%d;%dH", pos[i].y + 1 + row, pos[i].x + 1)
				for col in 0 ..< t.length {
					ch := t.text[row * t.length + col]
					fmt.printf("%c", ch if ch != 0 else ' ')
				}
			}
		}
	}
}
