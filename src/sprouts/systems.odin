package sprouts
import "../seeds"
import "base:intrinsics"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:time"

write_text :: proc(app: ^App, box: WidgetId, row: int, col: int, content: string) -> bool {
	tb := app_get(app, box, Text)
	area := app_get(app, box, Area)
	idx, ok := get_idx(area, row, col)
	if !ok {

		return false
	}
	for char in content {
		tb.text[idx] = char
		idx += 1
	}
	return true

}


get_idx :: #force_inline proc(box: ^Area, row: int, col: int) -> (int, bool) {
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
	fmt.eprintln("rebuild")

	for {
		time.sleep(50 * time.Millisecond)
		if !intrinsics.atomic_exchange(&g_window_resized, false) {break}
	}

	ok, _ := seeds.size()
	if !ok {
		return
	}

	delete(app.front)
	delete(app.back)
	screenspace := seeds.ws.column * seeds.ws.row
	app.front = make([]Screen_Buffer, screenspace)

	app.back = make([]Screen_Buffer, screenspace)
	slice.fill(app.front, Screen_Buffer{char = -1})
	slice.fill(app.back, Screen_Buffer{char = ' '})

	query := make_signature(Position, Area, Size_Scale, Postion_scale)
	archs := app_matching_archetypes(app, query[:])
	for arch in archs {
		sscale := archetype_data(arch, Size_Scale)
		pscale := archetype_data(arch, Postion_scale)
		text := archetype_data(arch, Area)
		pos := archetype_data(arch, Position)

		for i in 0 ..< len(sscale) {
			text[i].height = int(f32(seeds.ws.row) * sscale[i].height)
			text[i].length = int(f32(seeds.ws.column) * sscale[i].width)
		}
		for i in 0 ..< len(pscale) {
			pos[i].y = int(f32(seeds.ws.row) * pscale[i].y)
			pos[i].x = int(f32(seeds.ws.column) * pscale[i].x)
		}
	}
	fmt.eprintln("layout done, running resizers")
	app_run_resize(app)
}
get_screen_buff_index :: proc {
	get_screen_buff_index_2,
	get_screen_buff_index_3,
}
get_screen_buff_index_3 :: proc(x: int, y: int, pos: Position) -> int {
	return (pos.y + y) * int(seeds.ws.column) + (pos.x + x)
}
get_screen_buff_index_2 :: proc(x: int, y: int) -> int {
	return y * int(seeds.ws.column) + x
}
textbox_resize :: proc(app: ^App) {
	fmt.eprintln("textbox_resize called")


	query := make_signature(Position, Text, Area, Fg_Color, Bg_Color)
	archs := app_matching_archetypes(app, query[:])
	fmt.eprintln("matched archetypes:", len(archs))
	for arch in archs {
		text := archetype_data(arch, Text)
		area := archetype_data(arch, Area)

		fg := archetype_data(arch, Fg_Color)
		bg := archetype_data(arch, Bg_Color)
		ext := archetype_data(arch, Text)

		for i in 0 ..< len(area) {
			n := area[i].length * area[i].height
			if len(text[i].text) != n {resize(&text[i].text, n)}
			if len(fg[i].color) != n {resize(&fg[i].color, n)}
			if len(bg[i].color) != n {resize(&bg[i].color, n)}
			fmt.eprintln("resizing to", n, "bg was", len(bg[i].color))
		}

	}

}
draw_text_box :: proc(app: ^App, arch: ^Archetype, row: int) {
	text := archetype_data(arch, Text)[row]
	pos := archetype_data(arch, Position)[row]
	area := archetype_data(arch, Area)[row]
	fg := archetype_data(arch, Fg_Color)[row]
	bg := archetype_data(arch, Bg_Color)[row]
	for row in 0 ..< area.height {
		for col in 0 ..< area.length {
			idx := get_screen_buff_index(col, row, pos)
			inner, _ := get_idx(&area, row, col)
			fc := fg.color[inner]
			bc := bg.color[inner]
			ch := text.text[inner]
			if ch == 0 {ch = ' '}

			app.back[idx].char = ch
			app.back[idx].bg = bc
			app.back[idx].fg = fc
		}
	}
}


same_style :: #force_inline proc(a, b: Screen_Buffer) -> bool {
	return a.fg == b.fg && a.bg == b.bg && a.style == b.style
}
draw_buffer_diff :: proc(app: ^App) {
	assert(len(app.front) == len(app.back))

	strings.builder_reset(&seeds.frame_buffer)

	strings.write_string(&seeds.frame_buffer, seeds.SYNC_BEGIN)

	width := int(seeds.ws.column)
	count := len(app.back)

	changed := false

	i := 0

	for i < count {
		current := app.back[i]
		previous := app.front[i]

		if current == previous {
			i += 1
			continue
		}

		x := i % width
		y := i / width

		// Find the end of this run.
		end := i + 1

		for end < count {
			if end / width != y {
				break
			}

			if app.back[end] == app.front[end] {
				break
			}

			if !same_style(current, app.back[end]) {
				break
			}

			end += 1
		}

		// Move cursor once for this run.
		fmt.sbprintf(&seeds.frame_buffer, "\x1b[%d;%dH", y + 1, x + 1)

		// Set foreground/background.
		fmt.sbprintf(
			&seeds.frame_buffer,
			"\x1b[38;2;%d;%d;%dm",
			current.fg.r,
			current.fg.g,
			current.fg.b,
		)

		fmt.sbprintf(
			&seeds.frame_buffer,
			"\x1b[48;2;%d;%d;%dm",
			current.bg.r,
			current.bg.g,
			current.bg.b,
		)

		// Write consecutive characters.
		for j in i ..< end {
			fmt.sbprintf(&seeds.frame_buffer, "%c", app.back[j].char)
		}

		changed = true
		i = end
	}

	if !changed {
		strings.builder_reset(&seeds.frame_buffer)
		return
	}

	fmt.eprintln("write")

	strings.write_string(&seeds.frame_buffer, seeds.SYNC_END)

	os.write_string(os.stdout, strings.to_string(seeds.frame_buffer))

	copy(app.front, app.back)
}
