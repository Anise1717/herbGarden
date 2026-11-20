package sprouts
import "base:runtime"
destructor :: proc(p: rawptr)

Component_Info :: struct {
	id:      typeid,
	size:    int,
	align:   int,
	destroy: proc(ptr: rawptr),
}
component_info::proc{
	component_info_destroy,
	component_info_plain
}
component_info_plain :: proc($T: typeid) -> Component_Info {
	info := Component_Info {
		id    = T,
		size  = size_of(T),
		align = align_of(T),	
	}


	return info
}
component_info_destroy :: proc($T: typeid, $Destroy: proc(^T)) -> Component_Info {
	info := Component_Info {
		id    = T,
		size  = size_of(T),
		align = align_of(T),
		destroy = proc(ptr: rawptr) {
			Destroy((^T)(ptr))
		}
	}


	return info
}
component_zero::proc(info:Component_Info,dst:rawptr){
	runtime.mem_zero(dst,info.size)
}
component_move::proc(info:Component_Info,dst:rawptr,src:rawptr){
	runtime.mem_copy_non_overlapping(dst,src,info.size)
}
component_destroy::proc(info:Component_Info,ptr:rawptr){
	if info.destroy !=nil{
		info.destroy(ptr)
	}
}
