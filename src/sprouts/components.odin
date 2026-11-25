package sprouts
import"../seeds/"

Text::struct{
	text:[dynamic]rune,
}
Area::struct{
	length:int,
	height:int,
}
text_destroy::proc(text:^Text){
	delete(text.text)
}

Bg_Color::struct{
	color:[dynamic]seeds.color
}
Fg_Color::struct{
	color:[dynamic]seeds.color
}
fg_destroy::proc(fg:^Fg_Color){
	delete(fg.color)
}
bg_destroy::proc(bg:^Bg_Color){
	delete(bg.color)
}
Layer::struct{
	z:int
}
Size_Scale::struct{
	height:f32,
	width:f32,
}
Postion_scale::struct{
	x:f32,
	y:f32,
}
Position::struct{
	x:int,
	y:int,
}

