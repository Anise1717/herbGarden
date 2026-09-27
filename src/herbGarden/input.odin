package herbGarden

import "core:fmt"
import "core:os"

Key_Code :: enum {
	Up, Down, Left, Right,
	Home, End, Insert, Delete,
	PageUp, PageDown,
	F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
	Shift_Tab,
	Escape,
	Unknown,
}

Modifier :: enum { Shift, Alt, Ctrl }
Modifiers :: bit_set[Modifier]

Special_Key :: struct {
	code: Key_Code,
	mods: Modifiers,
}

Key :: union {
	rune,
	Special_Key,
	os.Error,
}

@(private)
read_byte :: proc(fd: ^os.File) -> (b: byte, ok: bool) {
	buf: [1]byte
	n, err := os.read(fd, buf[:])
	if n <= 0 || err != nil {
		return 0, false
	}
	return buf[0], true
}

keypress :: proc(fd: ^os.File) -> Key {
	b, ok := read_byte(fd)
	if !ok {
		fmt.print("os error\n")
		return os.Error{}
	}

	if b != 0x1b {
		return rune(b)
	}

	next, ok2 := read_byte(fd)
	if !ok2 {
		return Special_Key{code = .Escape}
	}

	switch next {
	case '[':
		return parse_csi(fd)
	case 'O':
		return parse_ss3(fd)
	case:
		return Special_Key{code = .Escape}

	}
}

@(private)
parse_ss3 :: proc(fd: ^os.File) -> Key {
	final, ok := read_byte(fd)
	if !ok {
		return Special_Key{code = .Escape}
	}
	switch final {
	case 'A': return Special_Key{code = .Up}
	case 'B': return Special_Key{code = .Down}
	case 'C': return Special_Key{code = .Right}
	case 'D': return Special_Key{code = .Left}
	case 'H': return Special_Key{code = .Home}
	case 'F': return Special_Key{code = .End}
	case 'P': return Special_Key{code = .F1}
	case 'Q': return Special_Key{code = .F2}
	case 'R': return Special_Key{code = .F3}
	case 'S': return Special_Key{code = .F4}
	case:     return Special_Key{code = .Unknown}
	}
}

@(private)
parse_csi :: proc(fd: ^os.File) -> Key {
	params: [16]byte
	count := 0

	for {
		b, ok := read_byte(fd)
		if !ok {
			return Special_Key{code = .Escape}
		}
		if b >= 0x40 && b <= 0x7e {
			return classify_csi(params[:count], b)
		}
		if count < len(params) {
			params[count] = b
			count += 1
		}
	}
}

@(private)
parse_params :: proc(params: []byte) -> (first: int, second: int) {
	cur := &first
	for b in params {
		if b == ';' {
			cur = &second
			continue
		}
		if b >= '0' && b <= '9' {
			cur^ = cur^ * 10 + int(b - '0')
		}
	}
	return
}

@(private)
mods_from_code :: proc(mod: int) -> (m: Modifiers) {
	switch mod {
	case 2: m = {.Shift}
	case 3: m = {.Alt}
	case 4: m = {.Shift, .Alt}
	case 5: m = {.Ctrl}
	case 6: m = {.Ctrl, .Shift}
	case 7: m = {.Ctrl, .Alt}
	case 8: m = {.Ctrl, .Alt, .Shift}
	}
	return
}

@(private)
with_mod :: proc(code: Key_Code, mod: int) -> Key {
	return Special_Key{code = code, mods = mods_from_code(mod)}
}

@(private)
classify_csi :: proc(params: []byte, final: byte) -> Key {
	if len(params) == 0 {
		switch final {
		case 'A': return Special_Key{code = .Up}
		case 'B': return Special_Key{code = .Down}
		case 'C': return Special_Key{code = .Right}
		case 'D': return Special_Key{code = .Left}
		case 'H': return Special_Key{code = .Home}
		case 'F': return Special_Key{code = .End}
		case 'Z': return Special_Key{code = .Shift_Tab}
		}
	}

	if final == '~' {
		num, mod := parse_params(params)
		switch num {
		case 1, 7:  return with_mod(.Home, mod)
		case 2:     return with_mod(.Insert, mod)
		case 3:     return with_mod(.Delete, mod)
		case 4, 8:  return with_mod(.End, mod)
		case 5:     return with_mod(.PageUp, mod)
		case 6:     return with_mod(.PageDown, mod)
		case 11:    return with_mod(.F1, mod)
		case 12:    return with_mod(.F2, mod)
		case 13:    return with_mod(.F3, mod)
		case 14:    return with_mod(.F4, mod)
		case 15:    return with_mod(.F5, mod)
		case 17:    return with_mod(.F6, mod)
		case 18:    return with_mod(.F7, mod)
		case 19:    return with_mod(.F8, mod)
		case 20:    return with_mod(.F9, mod)
		case 21:    return with_mod(.F10, mod)
		case 23:    return with_mod(.F11, mod)
		case 24:    return with_mod(.F12, mod)
		}
	}

	if final == 'A' || final == 'B' || final == 'C' || final == 'D' || final == 'H' || final == 'F' {
		_, mod := parse_params(params)
		code: Key_Code
		switch final {
		case 'A': code = .Up
		case 'B': code = .Down
		case 'C': code = .Right
		case 'D': code = .Left
		case 'H': code = .Home
		case 'F': code = .End
		}
		return with_mod(code, mod)
	}

	return Special_Key{code = .Unknown}
}
