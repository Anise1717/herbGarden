package sprouts

import "core:slice"
import"base:runtime"
import"core:mem"

Location::struct{
	arch:^Archetype,
	row:uint
}
App::struct{
	infos:map[typeid]^Component_Info,
	archetypes:[dynamic]^Archetype,
	buckets:map[uintptr][dynamic]^Archetype,
	locations:[dynamic]Location,
	free_list:[dynamic]WidgetId,
	root:^Archetype,
	allocator:runtime.Allocator,
}
app_init :: proc(app: ^App, allocator := context.allocator) {
	app.allocator  = allocator
	app.infos      = make(map[typeid]^Component_Info, allocator)
	app.archetypes = make([dynamic]^Archetype, allocator)
	app.buckets    = make(map[uintptr][dynamic]^Archetype, allocator)
	app.locations  = make([dynamic]Location, allocator)
	app.root       = app_get_archetype(app, nil)
}
app_register::proc(app:^App,info:Component_Info){
	p:=new(Component_Info,app.allocator)
	p^=info
	app.infos[info.id]=p
}
app_get_archetype::proc(app:^App,sig:[]typeid)->^Archetype{
	h:=signature_hash(sig)

	if bucket,ok:=app.buckets[h];ok{
		for a in bucket{
			if slice.equal(a.signature[:],sig){return a}
		}
	}
	infos:=make([]^Component_Info,len(sig),context.temp_allocator)
	for id,i in sig{
		info,ok:=app.infos[id]
		assert(ok,"component not registered")
		infos[i]=info
	}
	owned:= make(Signature,0,len(sig),app.allocator)
	append(&owned,..sig)
	arch:=new(Archetype,app.allocator)
	arch^= archetype_init(owned,infos,app.allocator)
	append(&app.archetypes,arch)
	bucket:=app.buckets[h]
	if bucket ==nil {bucket=make([dynamic]^Archetype,app.allocator)}
	append(&bucket,arch)
	app.buckets[h]=bucket
	return arch

}
app_spawn::proc(app:^App)->WidgetId{
	w:WidgetId
	if len(app.free_list)>0{
		w=pop(&app.free_list)	
	}
	else{
		w =len(&app.locations)
		append(&app.locations,Location{})
	}
	row:=archetype_add_widget(app.root,w)
	app.locations[w]=Location{app.root,w}
	return w
}


app_add :: proc(app: ^App, w: WidgetId, values: ..any) {
	src := app.locations[w].arch

	// Collect the types the entity doesn't have yet.
	missing := make([dynamic]typeid, 0, len(values), context.temp_allocator)
	for v in values {
		if !archetype_has(src, v.id) {
			append(&missing, v.id)
		}
	}

	// Move once, to the archetype containing everything.
	if len(missing) > 0 {
		dst: ^Archetype
		if len(missing) == 1 {
			dst = archetype_add_edge(src, missing[0])
		}
		if dst == nil {
			sig := make(Signature, 0, len(src.signature) + len(missing), context.temp_allocator)
			append(&sig, ..src.signature[:])
			append(&sig, ..missing[:])
			deduped(&sig)
			dst = app_get_archetype(app, sig[:])
			if len(missing) == 1 {
				archetype_set_add_edge(src, missing[0], dst)
				archetype_set_remove_edge(dst, missing[0], src)
			}
		}
		app_move(app, w, dst)
	}

	// Write the values into the entity's row.
	loc := app.locations[w]
	for v in values {
		col := find_column(loc.arch, v.id)
		assert(col != nil, "component type not registered")
		if col.info.size == 0 { continue }

		slot := column_at(col, uint(loc.row))
		if archetype_has(src, v.id) && col.info.destroy != nil {
			col.info.destroy(slot) // overwriting an existing value, free what it owned
		}
		mem.copy_non_overlapping(slot, v.data, col.info.size)
	}
}
app_remove :: proc(app: ^App, w: WidgetId, $T: typeid) {
	loc := &app.locations[w]
	src := loc.arch
	if !archetype_has(src, T) { return }

	dst := archetype_remove_edge(src, T)
	if dst == nil {
		sig := make(Signature, 0, len(src.signature), context.temp_allocator)
		for id in src.signature {
			if id != T { append(&sig, id) }
		}
		dst = world_get_archetype(w, sig[:])
		archetype_set_remove_edge(src, T, dst)
		archetype_set_add_edge(dst, T, src)
	}

	app_move(app, w, dst)
}
app_despawn::proc(app:^App,w:WidgetId){
	loc:=app.locations[w]
	swapped:=archetype_remove_widget(loc.arch,loc.row)
	if swapped!=INVALID_WIDGET{
		app.locations[swapped].row=loc.row

	}
	app.locations[w]=Location{}
	append(&app.free_list,w)
}
@(private)
app_move :: proc(app: ^App, w: WidgetId, dst: ^Archetype) {
	loc := &app.locations[w]
	res := archetype_move_widget(loc.arch, loc.row, dst)

	// The entity swapped into the vacated row needs its row updated.
	if res.swapped != INVALID_WIDGET{
		app.locations[res.swapped].row = loc.row
	}
	loc^ = Location{dst, res.new_row}
}
