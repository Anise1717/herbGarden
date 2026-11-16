package sprouts
import "base:runtime"

Move_Result :: struct {
	new_row: int,
	swapped: WidgetId,
}
Archetype :: struct {
	signature:    Signature,
	columns:      []Column,
	widgets:      [dynamic]WidgetId,
	add_edges:    map[typeid]^Archetype,
	remove_edges: map[typeid]^Archetype,
	allocator:    runtime.Allocator,
}
archetype_init :: proc(
	new_signature: Signature,
	infos: []Component_Info,
	new_allocator := context.allocator,
) -> Archetype {

	arch := Archetype {
		signature    = new_signature,
		allocator    = new_allocator,
		widgets      = make([dynamic]WidgetId, new_allocator),
		add_edges    = make(map[typeid]^Archetype, new_allocator),
		remove_edges = make(map[typeid]^Archetype, new_allocator),
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
archetype_destroy :: proc(arch: ^Archetype) {
	for &col in arch.columns {
		column_destroy_all(&col)
		column_release(&col)
	}
	delete(arch.columns, arch.allocator)
	delete(arch.widgets)
	delete(arch.add_edges)
	delete(arch.remove_edges)
	delete(arch.signature)
}
archetype_size :: proc(arch: ^Archetype) -> int {
	return len(arch.widgets)
}
archetype_is_empty :: proc(arch: ^Archetype) -> bool {
	return len(arch.widgets) == 0
}
archetype_widget_at :: proc(arch: ^Archetype, row: int) -> WidgetId {
	return arch.widgets[row]
}
archetype_has :: proc(arch: ^Archetype, id: typeid) -> bool {
	return contains_type(arch.signature[:], id)
}
archetype_has_all :: proc(arch: ^Archetype, ids: ..typeid) -> bool {
	for id in ids {
		if !archetype_has(arch, id) {return false}
	}
	return true
}
archetype_matches :: proc(arch: ^Archetype, query: []typeid) -> bool {
	j := 0
	for id in query {
		if j == len(query) {break}
		if id == query[j] {j += 1}
	}
	return j == len(query)
}
@(private)
find_column :: proc(arch: ^Archetype, id: typeid) -> ^Column {
	target := transmute(uintptr)id
	lo, hi := 0, len(arch.signature)
	for lo < hi {
		mid := lo + (hi - lo) / 2
		if transmute(uintptr)arch.signature[mid] < target {
			lo = mid + 1
		} else {
			hi = mid
		}
	}
	if lo < len(arch.signature) && arch.signature[lo] == id {
		return &arch.columns[lo]
	}
	return nil
}


archetype_data :: proc(arch: ^Archetype, $T: typeid) -> [^]T {
	c := find_column(arch, T)
	if c == nil {return nil}
	return ([^]T)(c.data)
}
archetype_get :: proc(arch: ^Archetype, row: int, $T: typeid) -> ^T {
	c := find_column(arch, T)
	assert(c != nil, "component not in archetype")
	return (^T)(column_at(c, uint(row)))
}
archetype_try_get :: proc(arch: ^Archetype, row: int, $T: typeid) -> ^T {
	c := find_column(arch, T)
	if c == nil {return nil}
	return (^T)(column_at(c, uint(row)))
}
arhctype_set :: proc(arch: ^Archetype, row: int, value: $T) {
	archetype_get(arch, row, T)^ = value
}

archetype_add_widget :: proc(arch: ^Archetype, row: int, widget: WidgetId) -> int {
	row := len(arch.widgets)
	for &col in arch.columns {
		column_push_empty(&col)
	}
	append(&arch.widgets, widget)
	return row
}
archetype_remove_entity :: proc(arch: ^Archetype, row: int) -> WidgetId {
	assert(row < len(arch.widgets))
	for &col in arch.columns {
		column_swap_remove(&col, uint(row))
	}
	swapped := INVALID_WIDGET
	if row != len(arch.widgets) - 1 {
		swapped = arch.widgets[len(arch.widgets) - 1]
	}
	unordered_remove(&arch.widgets, row)
	return swapped
}
archetype_move_entity :: proc(arch: ^Archetype, row: int, dst: ^Archetype) -> Move_Result {
	assert(row < len(arch.widgets))
	assert(dst != arch)

	widget := arch.widgets[row]
	for &dst_col in dst.columns {
		src_col := find_column(arch, dst_col.info.id)
		if src_col != nil {
			column_push_move(&dst_col, column_at(src_col, uint(row)))
		} else {
			column_push_empty(&dst_col)
		}
	}
	new_row := len(dst.widgets)
	append(&dst.widgets, widget)
	swapped := archetype_remove_entity(arch, row)
	return {new_row, swapped}
}
archetype_reserve::proc(arch:^Archetype,needed:int){
	reserve(&arch.widgets,needed)
	for &col in arch.columns{
		column_ensure_capacity(&col,uint(needed))
	}
}
archetype_add_edge::proc(arch:^Archetype,id:typeid)->^Archetype{
	return arch.add_edges[id] or_else nil
}
archetype_remove_edge::proc(arch:^Archetype,id:typeid)->^Archetype{
	return arch.remove_edges[id] or_else nil
}
archetype_set_add_edge :: proc(arch: ^Archetype, id: typeid, target: ^Archetype) {
	arch.add_edges[id] = target
}

archetype_set_remove_edge :: proc(arch: ^Archetype, id: typeid, target: ^Archetype) {
	arch.remove_edges[id] = target
}
