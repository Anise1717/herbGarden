package herbGarden

import "core:fmt"
import "core:mem"
import "core:strconv"
import "core:strings"
import "core:sys/posix"

FG_QUERY: string : "\e]10;?\a"
BG_QUERY: string : "\e]11;?\a"
DEFAULT_FG::color{255,255,255}
DEFAULT_BG::color{0,0,0}
//yes I know Odin has a soa tag, im stubborn
color :: struct {
	r, g, b: u8,
}
cell :: struct {
	alloc:           mem.Allocator,
	width:           u16,
	height:          u16,
	origin_x:        u16,
	origin_y:        u16,
	z:               i16,
	packed_verticle: bool,
	has_border:bool,
	x:               [dynamic]u16,
	y:               [dynamic]u16,
	character:       [dynamic]rune,
	foreground:      [dynamic]color,
	background:      [dynamic]color,
	dirty:           [dynamic]bool,
}
@(private)
query :: proc(request: string) -> string {
	fmt.print(request)

	buf: [64]u8
	n := posix.read(posix.STDIN_FILENO, raw_data(buf[:]), len(buf))
	if n <= 0 do return ""
	return fmt.tprintf("%s", string(buf[:n]))
}
@(private)
parse_color :: proc(reply: string) -> (c: color, ok: bool) {
	start := strings.index(reply, "rgb:")
	if start < 0 do return
	s := reply[start + 4:]

	// trim terminator (BEL or ESC \)
	end := strings.index_any(s, "\a\e")
	if end >= 0 do s = s[:end]

	parts := strings.split(s, "/", context.temp_allocator)
	if len(parts) != 3 do return

	channels: [3]u8
	for p, i in parts {
		v, parsed := strconv.parse_uint(p, 16)
		if !parsed do return
		// scale by digit count: 1 digit = 4 bits, 2 = 8, 3 = 12, 4 = 16
		switch len(p) {
		case 1:
			channels[i] = u8(v * 17)
		case 2:
			channels[i] = u8(v)
		case 3:
			channels[i] = u8(v >> 4)
		case 4:
			channels[i] = u8(v >> 8)
		case:
			return
		}
	}

	return color{channels[0], channels[1], channels[2]}, true
}
get_term_color :: proc(req: string) -> color {
	reply := query(req)
	if col,ok:=parse_color(reply);ok{
		return col
	}
	else if  req == FG_QUERY{
		return DEFAULT_FG
	}
	return DEFAULT_BG
}
create_cells :: proc(
	height: u16,
	width: u16,
	org_y: u16,
	org_x: u16,
	layer: i16 = 0,
	allocator := context.allocator,
	pack_verticle: bool = false,
) -> (
	result: cell,
	err: mem.Allocator_Error,
) {
	if height == 0 || width == 0 {
		err = .Invalid_Argument
		return
	}

	result.origin_x = org_x
	result.origin_y = org_y
	result.z = layer
	result.alloc = allocator
	result.width=width
	result.height=height
	result.has_border=false
	space_needed := int(width) * int(height)

	result.x = make([dynamic]u16, 0, 0, allocator)
	result.y = make([dynamic]u16, 0, 0, allocator)
	result.character = make([dynamic]rune, 0, 0, allocator)
	result.foreground = make([dynamic]color, 0, 0, allocator)
	result.background = make([dynamic]color, 0, 0, allocator)

	defer if err != nil {
		delete(result.x)
		delete(result.y)
		delete(result.character)
		delete(result.foreground)
		delete(result.background)
	}

	reserve(&result.x, space_needed) or_return
	reserve(&result.y, space_needed) or_return
	reserve(&result.character, space_needed) or_return
	reserve(&result.foreground, space_needed) or_return
	reserve(&result.background, space_needed) or_return
	reserve(&result.dirty, space_needed) or_return
	fg := get_term_color(FG_QUERY)
	bg := get_term_color(BG_QUERY)
	if pack_verticle {
		for ix in 0 ..< width {
			for iy in 0 ..< height {
				append(&result.x, ix) or_return
				append(&result.y, iy) or_return
				append(&result.character, ' ') or_return
				append(&result.foreground, fg) or_return
				append(&result.background, bg) or_return
				append(&result.dirty, true) or_return
			}

		}

		result.packed_verticle = true
	} else {
		for iy in 0 ..< height {
			for ix in 0 ..< width {
				append(&result.x, ix) or_return
				append(&result.y, iy) or_return
				append(&result.character, ' ') or_return
				append(&result.foreground, fg) or_return
				append(&result.background, bg) or_return
				append(&result.dirty, false) or_return
			}
		}

		result.packed_verticle = false
	}

	return
}
