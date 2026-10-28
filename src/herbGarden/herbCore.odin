
package herbGarden

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/posix"

/// Starts a synchronized update.
SYNC_BEGIN :: "\x1b[?2026h"

/// Ends a synchronized update.
SYNC_END :: "\x1b[?2026l"

/// Shared buffer that flush builds each frame in.
frame_buffer: strings.Builder

/// Selects the foreground or background color of a cell.
ColorArea :: enum {
	FG,
	BG,
}

/// The six strings used to draw a border.
Border_Glyphs :: struct {
	top_left, top_right:       string,
	bottom_left, bottom_right: string,
	horizontal, vertical:      string,
}

/// Box-drawing border.
BORDER_LINE :: Border_Glyphs{"┌", "┐", "└", "┘", "─", "│"}

/// Blank border, used to erase one.
BORDER_CLEAR :: Border_Glyphs{" ", " ", " ", " ", " ", " "}


/// Returns the array index of the cell at (x, y). No bounds checking.
get_cell_index :: #force_inline proc(window: ^cell, x: u16, y: u16) -> int {
	if window.packed_verticle {
		return int(window.height * x + y)
	}
	return int(window.width * y + x)
}

/// Adds a cursor move to frame_buffer. Cells are 0 indexed, 1 is added for ANSI.
move_cursor :: #force_inline proc(window: ^cell, x: u16, y: u16) {
	fmt.sbprintf(&frame_buffer, "\e[%d;%dH", window.origin_y + y + 1, window.origin_x + x + 1)
}

/// Adds one colored character to frame_buffer.
hprint :: #force_inline proc(char: rune, fg: color, bg: color) {
	fmt.sbprintf(
		&frame_buffer,
		"\e[38;2;%d;%d;%dm\e[48;2;%d;%d;%dm%c\e[0m",
		fg.r, fg.g, fg.b,
		bg.r, bg.g, bg.b,
		char,
	)
}

/// Draws all dirty cells in one synchronized write. Does nothing if none are dirty.
flush :: proc(window: ^cell) -> bool {
	strings.builder_reset(&frame_buffer)
	strings.write_string(&frame_buffer, SYNC_BEGIN)

	for x, index in window.x {
		y := window.y[index]
		if x >= window.width || y >= window.height || !window.dirty[index] {
			continue
		}
		move_cursor(window, x, y)
		hprint(window.character[index], window.foreground[index], window.background[index])
		window.dirty[index] = false
	}

	if strings.builder_len(frame_buffer) == len(SYNC_BEGIN) {
		return true
	}

	strings.write_string(&frame_buffer, SYNC_END)
	os.write_string(os.stdout, strings.to_string(frame_buffer))
	return true
}


/// Writes text starting at (start_x, start_y). Clips at the right edge.
/// Returns false if the start is outside the window.
write :: proc(window: ^cell, start_x: u16, start_y: u16, content: string) -> bool {
	if start_x >= window.width || start_y >= window.height do return false

	x := start_x
	for char in content {
		if x >= window.width do break
		index := get_cell_index(window, x, start_y)
		window.character[index] = char
		window.dirty[index] = true
		x += 1
	}
	return true
}

/// Sets the color of one cell. Sets foreground by default.
/// Returns false if (x, y) is outside the window.
set_color :: proc(
	window: ^cell,
	x: u16,
	y: u16,
	new_color: color,
	color_area: ColorArea = .FG,
) -> bool {
	if x >= window.width || y >= window.height do return false

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

/// Sets the color of every cell. Sets background by default.
fill :: proc(window: ^cell, new_color: color, color_area: ColorArea = .BG) {
	colors := window.background[:]
	if color_area == .FG {
		colors = window.foreground[:]
	}
	for &c, index in colors {
		c = new_color
		window.dirty[index] = true
	}
}


/// Draws a border with the given glyphs. Needs a window of at least 2x2.
@(private)
write_border :: proc(window: ^cell, glyphs: Border_Glyphs) {
	if window.width < 2 || window.height < 2 do return

	left, top := u16(0), u16(0)
	right, bottom := window.width - 1, window.height - 1

	write(window, left, top, glyphs.top_left)
	write(window, right, top, glyphs.top_right)
	write(window, left, bottom, glyphs.bottom_left)
	write(window, right, bottom, glyphs.bottom_right)

	for x in left + 1 ..< right {
		write(window, x, top, glyphs.horizontal)
		write(window, x, bottom, glyphs.horizontal)
	}
	for y in top + 1 ..< bottom {
		write(window, left, y, glyphs.vertical)
		write(window, right, y, glyphs.vertical)
	}
}

/// Draws a border around the window and sets has_border.
draw_border :: proc(window: ^cell) {
	window.has_border = true
	write_border(window, BORDER_LINE)
}

/// Erases the border. Does not change has_border.
clear_border :: proc(window: ^cell) {
	write_border(window, BORDER_CLEAR)
}


/// Returns true if the cell at index is on the window's edge.
@(private)
is_border_cell ::#force_inline proc(window: ^cell, index: int) -> bool {
	x, y := window.x[index], window.y[index]
	return x == 0 || y == 0 || x == window.width - 1 || y == window.height - 1
}

/// Replaces all text with spaces. Keeps the border if has_border is set.
clear_text :: proc(window: ^cell) {
	for index in 0 ..< len(window.character) {
		if window.has_border && is_border_cell(window, index) {
			continue
		}
		window.character[index] = ' '
		window.dirty[index] = true
	}
}

/// Resets every foreground to the terminal's foreground color.
clear_foreground :: proc(window: ^cell) {
	term_fg := get_term_color(FG_QUERY)
	for index in 0 ..< len(window.character) {
		window.foreground[index] = term_fg
		window.dirty[index] = true
	}
}

/// Resets every background to a terminal color.
clear_background :: proc(window: ^cell) {
	term_color := get_term_color(FG_QUERY)
	for index in 0 ..< len(window.character) {
		window.background[index] = term_color
		window.dirty[index] = true
	}
}

/// Clears the background, foreground and text.
clear_buffer :: proc(window: ^cell) {
	clear_background(window)
	clear_foreground(window)
	clear_text(window)
}


/// Resizes and moves a window, then flushes it.
/// Cells that still fit keep their contents. Height comes before width.
resize_cells :: proc(window: ^cell, height, width, origin_y, origin_x: u16) {
	if window.has_border {
		clear_border(window)
	}

	old_w := int(window.width)
	old_h := int(window.height)
	old_count := len(window.character)

	// Snapshot the old contents so they can be remapped into the new layout.
	old_char := make([]rune, old_count, window.alloc)
	old_fg := make([]color, old_count, window.alloc)
	old_bg := make([]color, old_count, window.alloc)
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

	window.width = width
	window.height = height
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
			window.character[i] = old_char[old_i]
			window.foreground[i] = old_fg[old_i]
			window.background[i] = old_bg[old_i]
		} else {
			window.character[i] = ' '
			window.foreground[i] = fg
			window.background[i] = bg
		}
	}

	if window.has_border {
		draw_border(window)
	}
	flush(window)
}


/// Reads digits from buf starting at *i and advances *i past them.
@(private)
parse_digits :: proc(buf: []u8, i: ^int) -> (value: u32) {
	for i^ < len(buf) && buf[i^] >= '0' && buf[i^] <= '9' {
		value = value * 10 + u32(buf[i^] - '0')
		i^ += 1
	}
	return
}

/// Asks the terminal for the cursor position. Row and column are 1 based.
/// ok is false if there is no reply within one second. Unix only.
get_cursor_position :: proc() -> (row, col: u16, ok: bool) {
	orig: posix.termios
	if posix.tcgetattr(posix.STDIN_FILENO, &orig) != .OK do return
	defer posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &orig)

	raw := orig
	raw.c_lflag -= {.ICANON, .ECHO}
	raw.c_cc[.VMIN] = 0
	raw.c_cc[.VTIME] = 10 // 1 second read timeout
	if posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &raw) != .OK do return

	query := "\x1b[6n"
	if posix.write(posix.STDOUT_FILENO, raw_data(query), uint(len(query))) < 0 do return

	// Response format: ESC [ <row> ; <col> R
	buf: [32]u8
	n := 0
	for n < len(buf) {
		if posix.read(posix.STDIN_FILENO, &buf[n], 1) != 1 do return
		n += 1
		if buf[n - 1] == 'R' do break
	}

	resp := buf[:n]
	if len(resp) < 6 || resp[0] != 0x1b || resp[1] != '[' || resp[n - 1] != 'R' do return

	i := 2
	r := parse_digits(resp, &i)
	if i >= n || resp[i] != ';' do return
	i += 1
	c := parse_digits(resp, &i)

	return u16(r), u16(c), true
}

