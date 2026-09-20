package main
import "core:fmt"
import "core:terminal"
import "core:os"
main::proc(){
	fmt.print("hello");
	fmt.print(terminal.is_terminal(os.stdout));
}

