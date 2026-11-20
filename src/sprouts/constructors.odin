package sprouts
make_text_box::proc(app:^App,x_pos:f32,y_pos:f32,length:f32,height:f32)->WidgetId{
	id:=app_spawn(app)
	sscale:=Size_Scale{height,length}	
	pscale:=Postion_scale{x_pos,y_pos}
	//remove later
	text:=Text{text=make([dynamic]rune,app.allocator)}
	app_add(app,id,sscale,pscale,text,Position{})
	return id
}
