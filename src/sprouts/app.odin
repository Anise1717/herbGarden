package sprouts


import "../seeds"
import "base:intrinsics"
import "base:runtime"
import "core:mem"
import "core:slice"
import "core:sys/linux"
import "core:sys/posix"

SIGWINCH :: posix.Signal(28)
g_window_resized: bool = true
Location :: struct {
	arch: ^Archetype,
	row:  int,
}
Draw_Proc::proc(app:^App,arch:^Archetype,row:int)
Drawer :: struct {
	query: Signature,
	draw:  Draw_Proc,
}
Resize_proc :: proc(app: ^App)

Draw_item :: struct {
	z:         int,
	arch:      ^Archetype,
	row:       int,
	draw_proc: ^Drawer,
}
sigwinch_handler :: proc "c" (sig: posix.Signal) {
	intrinsics.atomic_store(&g_window_resized, true)
}
init_sigwinch :: proc() {
	sa: posix.sigaction_t
	sa.sa_handler = sigwinch_handler
	posix.sigemptyset(&sa.sa_mask)
	sa.sa_flags = {}
	posix.sigaction(SIGWINCH, &sa, nil)
}
Screen_Buffer :: struct {
	char:  rune,
	fg:    seeds.color,
	bg:    seeds.color,
	style: seeds.Text_Style,
}

App :: struct {
	infos:       map[typeid]^Component_Info,
	archetypes:  [dynamic]^Archetype,
	buckets:     map[uintptr][dynamic]^Archetype,
	locations:   [dynamic]Location,
	free_list:   [dynamic]WidgetId,
	root:        ^Archetype,
	drawers:     [dynamic]Drawer,
	resize_proc: [dynamic]Resize_proc,
	front:       []Screen_Buffer,
	back:        []Screen_Buffer,
	allocator:   runtime.Allocator,
}
app_init :: proc(app: ^App, allocator := context.allocator) {
	app.allocator = allocator
	app.infos = make(map[typeid]^Component_Info, allocator)
	app.archetypes = make([dynamic]^Archetype, allocator)
	app.buckets = make(map[uintptr][dynamic]^Archetype, allocator)
	app.locations = make([dynamic]Location, allocator)
	app.drawers = make([dynamic]Drawer, allocator)
	app.resize_proc = make([dynamic]Resize_proc, allocator)
	app.root = app_get_archetype(app, nil)
	init_sigwinch()
	seeds.enable_raw()

}
app_register :: proc {
	app_register_destroy,
	app_register_info,
	app_register_plain,
}
app_register_plain :: proc(app: ^App, $T: typeid) {
	app_register_info(app, component_info(T))
}
app_register_destroy :: proc(app: ^App, $T: typeid, $Destroy: proc(_: ^T)) {
	app_register_info(app, component_info(T, Destroy))
}
app_register_info :: proc(app: ^App, info: Component_Info) {
	p := new(Component_Info, app.allocator)
	p^ = info
	app.infos[info.id] = p
}
app_get_archetype :: proc(app: ^App, sig: []typeid) -> ^Archetype {
	h := signature_hash(sig)

	if bucket, ok := app.buckets[h]; ok {
		for a in bucket {
			if slice.equal(a.signature[:], sig) {return a}
		}
	}
	infos := make([]^Component_Info, len(sig), context.temp_allocator)
	for id, i in sig {
		infos[i] = app_ensure_registered(app, id)
	}
	owned := make(Signature, 0, len(sig), app.allocator)
	append(&owned, ..sig)
	arch := new(Archetype, app.allocator)
	arch^ = archetype_init(owned, infos, app.allocator)
	append(&app.archetypes, arch)
	bucket := app.buckets[h]
	if bucket == nil {bucket = make([dynamic]^Archetype, app.allocator)}
	append(&bucket, arch)
	app.buckets[h] = bucket
	return arch

}
app_register_draw :: proc(app: ^App,sig:Signature, draw: Draw_Proc) {
	append(&app.drawers,Drawer{sig,draw})
}
app_register_resize :: proc(app: ^App, resize: Resize_proc) {
	append(&app.resize_proc, resize)
}
app_run_draw :: proc(app: ^App) {
	items := make([dynamic]Draw_item, 0, 64, context.temp_allocator)
	for &draw in app.drawers {
		q := make_signature(Layer, allocator = context.temp_allocator)
		append(&q, ..draw.query[:])
		deduped(&q)
		for arch in app_matching_archetypes(app, q[:]) {
			layer := archetype_data(arch, Layer)
			for i in 0 ..< len(layer) {
				append(&items, Draw_item{layer[i].z, arch, i, &draw})
			}
		}
	}
	slice.stable_sort_by(items[:],proc(a,b:Draw_item)->bool{return a.z<b.z})
	for it in items{
		it.draw_proc.draw(app,it.arch,it.row)
	}
}
app_run_resize :: proc(app: ^App) {
	for r in app.resize_proc {
		r(app)
	}
}
app_get :: proc(app: ^App, w: WidgetId, $T: typeid) -> ^T {
	loc := app.locations[w]
	if loc.arch == nil {return nil}
	return archetype_try_get(loc.arch, loc.row, T)
}
app_spawn :: proc(app: ^App) -> WidgetId {
	w: WidgetId
	if len(app.free_list) > 0 {
		w = pop(&app.free_list)
	} else {
		w = len(&app.locations)
		append(&app.locations, Location{})
	}
	row := archetype_add_widget(app.root, w)
	app.locations[w] = Location{app.root, int(w)}
	return w
}
app_matching_archetypes :: proc(
	app: ^App,
	query: []typeid,
	allocator := context.temp_allocator,
) -> [dynamic]^Archetype {
	result := make([dynamic]^Archetype, 0, len(app.archetypes), allocator)
	for arch in app.archetypes {
		if !archetype_is_empty(arch) && archetype_matches(arch, query) {
			append(&result, arch)
		}
	}
	return result
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
		if col.info.size == 0 {continue}

		slot := column_at(col, loc.row)
		if archetype_has(src, v.id) && col.info.destroy != nil {
			col.info.destroy(slot) // overwriting an existing value, free what it owned
		}
		mem.copy_non_overlapping(slot, v.data, col.info.size)
	}
}
app_ensure_registered :: proc(app: ^App, id: typeid) -> ^Component_Info {
	if info, ok := app.infos[id]; ok {return info}
	ti := type_info_of(id)
	p := new(Component_Info, app.allocator)
	p^ = Component_Info {
		id    = id,
		size  = ti.size,
		align = ti.align,
	}
	app.infos[id] = p
	return p
}

app_remove :: proc(app: ^App, w: WidgetId, $T: typeid) {
	loc := &app.locations[w]
	src := loc.arch
	if !archetype_has(src, T) {return}

	dst := archetype_remove_edge(src, T)
	if dst == nil {
		sig := make(Signature, 0, len(src.signature), context.temp_allocator)
		for id in src.signature {
			if id != T {append(&sig, id)}
		}
		dst = app_get_archetype(w, sig[:])
		archetype_set_remove_edge(src, T, dst)
		archetype_set_add_edge(dst, T, src)
	}

	app_move(app, w, dst)
}
app_despawn :: proc(app: ^App, w: WidgetId) {
	loc := app.locations[w]
	swapped := archetype_remove_widget(loc.arch, loc.row)
	if swapped != INVALID_WIDGET {
		app.locations[swapped].row = loc.row

	}
	app.locations[w] = Location{}
	append(&app.free_list, w)
}
@(private)
app_move :: proc(app: ^App, w: WidgetId, dst: ^Archetype) {
	loc := &app.locations[w]
	res := archetype_move_widget(loc.arch, loc.row, dst)

	// The entity swapped into the vacated row needs its row updated.
	if res.swapped != INVALID_WIDGET {
		app.locations[res.swapped].row = loc.row
	}
	loc^ = Location{dst, res.new_row}
}
