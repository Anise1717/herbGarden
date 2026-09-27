package herbGarden
import"core:fmt"
import"core:terminal/ansi"

get_cell_index::#force_inline proc(window:^cell,x:u16,y:u16)->int{
	if window.packed_verticle{
		return cast(int) (window.height*x+y)
	}
	else{
		return cast(int) (window.width*y+x)
	}
}
move_cursor::#force_inline proc(x:u16,y:u16){

	fmt.printf("%s%d;%d%s",ansi.CSI,x+1,y+1,ansi.CUP)
}
