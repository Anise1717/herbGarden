package herbGarden
import "core:fmt"
import"core:slice"
import "core:terminal/ansi"
ColorArea :: enum {
	FG,
	BG,
}
get_cell_index :: #force_inline proc(window: ^cell, x: u16, y: u16) -> int {
	if window.packed_verticle {
		return cast(int)(window.height * x + y)
	} else {
		return cast(int)(window.width * y + x)
	}
}
///Cells are 0 indexed, this function adds 1 to coords to account for ANSI setting top left as (1,1)
move_cursor :: #force_inline proc(window: ^cell, x: u16, y: u16) {
	fmt.printf("\e[%d;%dH", window.origin_y + y + 1, window.origin_x + x + 1)
}
write :: proc(window: ^cell, start_x: u16, start_y: u16, content: string) -> bool {
	index := get_cell_index(window, start_x, start_y)
	if start_x > window.width || start_y > window.height do return false
	for char in content {
		window.character[index] = char
		window.dirty[index] = true
		index += 1
	}
	return true
}
///setting BG to true sets background color, by defualt Foreground color is set
set_color :: proc(
	window: ^cell,
	x: u16,
	y: u16,
	new_color: color,
	color_area: ColorArea = ColorArea.FG,
) -> bool {

	if x > window.width || y > window.height do return false
	index := get_cell_index(window, x, y)
	switch color_area {
	case .BG:
		window.background[index] = new_color
	case .FG:
		window.foreground[index] = new_color
	}
	window.dirty[index] = true
	return true
}

flush :: proc(window: ^cell) -> bool {
	for x, index in window.x {
		if x >= window.width || window.y[index] >= window.height {
			continue
		}
		if window.dirty[index] {
			move_cursor(window, x, window.y[index])
			hprint(window.character[index], window.foreground[index], window.background[index])
			window.dirty[index] = false
		}
	}
	return true
}
draw_border :: proc(window: ^cell) {
	left: u16 = 0
	top: u16 = 0
	right: u16 = window.width - 1
	bottom: u16 = window.height - 1
	window.has_border = true

	write(window, left, top, "┌")
	write(window, left, bottom, "└")
	write(window, right, top, "┐")
	write(window, right, bottom, "┘")

	for index in left + 1 ..< right {
		write(window, index, top, "─")
		write(window, index, bottom, "─")
	}
	for index in top + 1 ..< bottom {
		write(window, left, index, "│")
		write(window, right, index, "│")
	}
}
clear_border :: proc(window: ^cell) {
	left: u16 = 0
	top: u16 = 0
	right: u16 = window.width - 1
	bottom: u16 = window.height - 1
	window.has_border = true

	write(window, left, top, " ")
	write(window, left, bottom, " ")
	write(window, right, top, " ")
	write(window, right, bottom, " ")

	for index in left + 1 ..< right {
		write(window, index, top, " ")
		write(window, index, bottom, " ")
	}
	for index in top + 1 ..< bottom {
		write(window, left, index, " ")
		write(window, right, index, " ")
	}
}
hprint :: #force_inline proc(char: rune, fg: color, bg: color) {
	fmt.printf(
		"\e[38;2;%d;%d;%dm\e[48;2;%d;%d;%dm%c\e[0m",
		fg.r,
		fg.g,
		fg.b,
		bg.r,
		bg.g,
		bg.b,
		char,
	)
}
///fills a window with the desired color in either the foreground or background
fill :: proc(window: ^cell, new_color: color, color_area: ColorArea = .BG) {
	if color_area == .FG {
		for &cell, index in window.foreground {
			cell = new_color
			window.dirty[index] = true
		}

	} else {
		for &cell, index in window.background {
			cell = new_color
			window.dirty[index] = true
		}
	}
}
resize_cells :: proc(window: ^cell, height, width, origin_y, origin_x: u16) {
	if window.has_border{
	clear_border(window)
	}
	old_w := int(window.width)
	old_h := int(window.height)
	old_count := len(window.character)

	// snapshot the old data
	old_char := make([]rune, old_count, window.alloc)
	old_fg   := make([]color, old_count, window.alloc)
	old_bg   := make([]color, old_count, window.alloc)
	defer delete(old_char, window.alloc)
	defer delete(old_fg, window.alloc)
	defer delete(old_bg, window.alloc)
	copy(old_char, window.character[:])
	copy(old_fg, window.foreground[:])
	copy(old_bg, window.background[:])

	fg, bg := DEFAULT_FG, DEFAULT_BG
	if old_count > 0 {
		fg = old_fg[0]
		bg = old_bg[0]
	}

	window.width    = width
	window.height   = height
	window.origin_x = origin_x
	window.origin_y = origin_y

	count := int(width) * int(height)

	resize(&window.x, count)
	resize(&window.y, count)
	resize(&window.character, count)
	resize(&window.foreground, count)
	resize(&window.background, count)
	resize(&window.dirty, count)

	for i in 0 ..< count {
		x, y: int
		if window.packed_verticle {
			x = i / int(height)
			y = i % int(height)
		} else {
			x = i % int(width)
			y = i / int(width)
		}

		window.x[i] = u16(x)
		window.y[i] = u16(y)
		window.dirty[i] = true

		if x < old_w && y < old_h {
			old_i := window.packed_verticle ? x * old_h + y : y * old_w + x
			window.character[i]  = old_char[old_i]
			window.foreground[i] = old_fg[old_i]
			window.background[i] = old_bg[old_i]
		} else {
			window.character[i]  = ' '
			window.foreground[i] = fg
			window.background[i] = bg
		}
	}

	if window.has_border {
		draw_border(window)
	}
	flush(window)
}
