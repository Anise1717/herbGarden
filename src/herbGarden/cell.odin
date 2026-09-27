package herbGarden

import "core:mem"

//yes I know Odin has a soa tag, im stubborn
///if you need Z layer do it yourself
cell :: struct {
	alloc:      mem.Allocator,
	x:          [dynamic]u16,
	y:          [dynamic]u16,
	character:  [dynamic]rune,
	foreground: [dynamic]string,
	background: [dynamic]string,
}

create_cells :: proc(
	height: u16,
	width: u16,
	allocator := context.allocator,
	pack_verticle: bool = false,
) -> (result: cell, err: mem.Allocator_Error) {
	if height == 0 || width == 0 {
		err = .Invalid_Argument
		return
	}

	result.alloc = allocator
	space_needed := int(width) * int(height)

	result.x = make([dynamic]u16, 0, 0, allocator)
	result.y = make([dynamic]u16, 0, 0, allocator)
	result.character = make([dynamic]rune, 0, 0, allocator)
	result.foreground = make([dynamic]string, 0, 0, allocator)
	result.background = make([dynamic]string, 0, 0, allocator)

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

	if pack_verticle {
		for ix in 0 ..< width {
			for iy in 0 ..< height {
				append(&result.x, ix) or_return
				append(&result.y, iy) or_return
				append(&result.character, ' ') or_return
				append(&result.foreground, "") or_return
				append(&result.background, "") or_return
			}
		}
	} else {
		for iy in 0 ..< height {
			for ix in 0 ..< width {
				append(&result.x, ix) or_return
				append(&result.y, iy) or_return
				append(&result.character, ' ') or_return
				append(&result.foreground, "") or_return
				append(&result.background, "") or_return
			}
		}
	}

	return
}
