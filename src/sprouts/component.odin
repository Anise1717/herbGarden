package sprouts
ComponentId :: uint
contructor::proc(rawptr)
destructor::proc(rawptr)
move_con::proc(rawptr,rawptr)

next_component_id :: #force_inline proc() -> ComponentId {
	@static current_comp_id :ComponentId= 0	
	current_comp_id += 1
	return current_comp_id
}

ComponentInfo::struct{
	id:ComponentId,
	size:int,
	align:int,
	new:contructor,
	delete:destructor,
	move:move_con,
}
