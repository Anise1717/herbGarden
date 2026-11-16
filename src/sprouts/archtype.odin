package sprouts
import "base:runtime"

Move_Result :: struct {
	new_row: uint,
	swapped: WidgetId,
}
Archtype :: struct {
	signature:    Signature,
	columns:      []Column,
	widgets:      [dynamic]WidgetId,
	add_edges:    map[typeid]^Archtype,
	remove_edges: map[typeid]^Archtype,
	allocator:    runtime.Allocator,
}
archtype_init :: proc(
	new_signature: Signature,
	infos: []Component_Info,
	new_allocator := context.allocator,
) -> Archtype {

	arch := Archtype {
		signature    = new_signature,
		allocator    = new_allocator,
		widgets      = make([dynamic]WidgetId, new_allocator),
		add_edges    = make(map[typeid]^Archtype, new_allocator),
		remove_edges = make(map[typeid]^Archtype, new_allocator),
	}
	deduped(&arch.signature)

	arch.columns = make([]Column, len(arch.signature), arch.allocator)
	for id, i in arch.signature {
		found := false
		for &info in infos {
			if info.id == id {
				arch.columns[i] = column_init(&info, new_allocator)
				found = true
				break
			}
		}
		assert(found, "missing component_info for signature entry")
	}
	return arch
}
