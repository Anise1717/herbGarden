package sprouts
ComponentId :: uint
contructor :: proc(dst: rawptr)
destructor :: proc(p: rawptr)
move_con :: proc(dst: rawptr, src: rawptr)

next_component_id :: #force_inline proc() -> ComponentId {
	@(static) current_comp_id: ComponentId = 0
	current_comp_id += 1
	return current_comp_id
}

ComponentInfo :: struct {
	id:     ComponentId,
	size:   int,
	align:  int,
	new:    contructor,
	delete: destructor,
	move:   move_con,
}

component_info :: proc($T: typeid) -> ComponentInfo {
	@(static) info: ComponentInfo
	@(static) initialized: bool

	if !initialized {
		info = ComponentInfo {
			id = next_component_id(),
			size = size_of(T),
			align = align_of(T),
			new = contructor(){(^T)(dst)^ = T{}},
			delete = destructor(){destroy_owned(p, type_info_of(T))},
			move = move_con(){(^T)(dst)^ = (^T)(src)^},
		}


		initialized = true
	}

	return info
}
