package sprouts
import "../seeds/"
make_text_box :: proc(
	app: ^App,
	x_pos: f32,
	y_pos: f32,
	length: f32,
	height: f32,
	layer:Layer={1},
	fg: seeds.color = {},
	bg: seeds.color = {},
) -> WidgetId {
	fg := fg
	bg := bg
	id := app_spawn(app)
	sscale := Size_Scale{height, length}
	pscale := Postion_scale{x_pos, y_pos}
	nfg := Fg_Color {
		color = make([dynamic]seeds.color, 1, app.allocator),
	}
	if fg == {} {
		fg = seeds.get_term_color(seeds.FG_QUERY)
	}
	if bg == {} {
		bg = seeds.get_term_color(seeds.BG_QUERY)
	}
	nfg.color[0] = fg
	nbg := Bg_Color {
		color = make([dynamic]seeds.color, 1, app.allocator),
	}
	text := Text {
		text = make([dynamic]rune, app.allocator),
	}
	app_add(app, id, sscale, pscale, text, Position{},layer, Area{}, nfg, nbg)
	return id
}
register_text_box :: proc(app: ^App) {
	sig := make_signature(Position, Text, Size_Scale, Postion_scale, Area, Fg_Color, Bg_Color)

	deduped(&sig)
	app_register(app, Text, text_destroy)
	app_register(app, Bg_Color, bg_destroy)
	app_register(app, Fg_Color, fg_destroy)
	app_register_resize(app, textbox_resize)
	app_register_draw(app, sig, draw_text_box)

}
