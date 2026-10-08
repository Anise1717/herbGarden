package herbGarden
import "core:fmt"
import "core:terminal/ansi"

get_cell_index :: #force_inline proc(window: ^cell, x: u16, y: u16) -> int {
	if window.packed_verticle {
		return cast(int)(window.height * x + y)
	} else {
		return cast(int)(window.width * y + x)
	}
}
move_cursor :: #force_inline proc(window: ^cell, x: u16, y: u16) {
	fmt.printf("\e[%d;%dH", window.origin_y + y + 1, window.origin_x + x + 1)
}
write :: proc(window: ^cell, start_x: u16, start_y: u16, content: string) -> bool {
	index := get_cell_index(window, start_x, start_y)
	if start_x > window.width || start_y > window.height do return false
	for char in content {
		window.character[index] = char
		window.dirty[index]=true
		index+=1
	}
	return true
}
set_bg_color :: proc(window: ^cell, x: u16, y: u16,bg_color:color) -> bool {
	if x > window.width || y > window.height do return false
	index := get_cell_index(window, x, y)
	window.background[index]=bg_color;
	window.dirty[index]=true;
	return true
}
set_fg_color :: proc(window: ^cell, x: u16, y: u16,fg_color:color) -> bool {
	if x > window.width || y > window.height do return false
	index := get_cell_index(window, x, y)
	window.foreground[index]=fg_color;
	window.dirty[index]=true;
	return true
}
flush::proc(window:^cell)->bool{
	for x,index in window.x{
		if window.dirty[index]{
			move_cursor(window,x,window.y[index])
			hprint(window.character[index],window.foreground[index],window.background[index])
			window.dirty[index]=false
		}
	}
	return true
}
hprint::#force_inline proc(char:rune,fg:color,bg:color){
    fmt.printf("\e[38;2;%d;%d;%dm\e[48;2;%d;%d;%dm%c\e[0m",
        fg.r, fg.g, fg.b,
        bg.r, bg.g, bg.b,
        char)
}
