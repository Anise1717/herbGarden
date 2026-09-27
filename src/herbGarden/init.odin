package herbGarden

import "core:fmt"
import "core:os"
import "core:sys/linux"
import "core:sys/posix"
import "core:terminal/ansi"
import "core:mem"

winsize :: struct {
	row:    u16,
	column: u16,
	xpixel: u16,
	ypixel: u16,
}
origin_state: posix.termios
ws: winsize

enable_raw :: proc() -> bool {
	if posix.tcgetattr(0, &origin_state) != posix.result.OK do return false

	raw := origin_state
	raw.c_lflag &~= {.ECHO, .ICANON, .IEXTEN, .ISIG}
	raw.c_iflag &~= {.IXON, .ICRNL, .BRKINT, .INPCK, .ISTRIP}
	raw.c_oflag &~= {.OPOST}
	raw.c_cc[.VMIN] = 1
	raw.c_cc[.VTIME] =0
	if posix.tcsetattr(0, .TCSAFLUSH, &raw) != posix.result.OK do return false
	return true
}
disable_raw :: proc() {
	posix.tcsetattr(0, .TCSAFLUSH, &origin_state)
}
init_window :: proc(alloc:=context.allocator,pack_verticle:=false) -> (bool,cell) {
	if !enable_raw() do return false,{}

	if linux.ioctl(0, linux.TIOCGWINSZ,uintptr(&ws)) != 0 do return false,{}
	fmt.printf("raw")
	result,err:= create_cells(ws.row,ws.column,alloc,pack_verticle);
	if err!= nil do return false,{}
	return true, result
}

