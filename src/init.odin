package herbGarden

import "core:fmt"
import "core:os"
import "core:sys/posix"
import "core:sys/linux"
import "core:os"

winsize::struct {
	row:u16,
	column:u16,
	xpixel:u16,
	ypixel:u16,
}
origin_state: posix.termios
ws: linux.win 

enable_raw::proc()->bool{
	if posix.tcgetattr(0,&origin_state)!= 0 do return false

	raw := origin_state;
	raw.c_lflag &= ~(posix.ECHO | posix.ICANON| posix.IEXTEN| posix.ISIG);
	raw.c_iflag &= ~(posix.IXON|posix.ICRNL|posix.BRKINT|posix.INPCK|posix.ISTRIP);
	raw.c_oflag&=~(posix.OPOST);
	raw.c_cc[posix.VMIN]=0;
	raw.c_cc[posix.VTIME]=1;
	if posix.tcsetattr(0,.TCSAFLUSH,&raw)!=0 do return false;
	return true;
}
disable_raw::proc(){
	posix.tcsetattr(0,.TCSAFLUSH,&origin_state)
}
init_window::proc()->bool{
	if !enable_raw() do return false

	if posix.ioctl
}
