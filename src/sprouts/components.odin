package sprouts

Text::struct{
	length:int,
	height:int,
	text:[dynamic]rune,
}
text_destroy::proc(text:^Text){
	delete(text.text)
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

