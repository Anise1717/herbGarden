package herbGarden

import "core:terminal/ansi"

point:: struct{
	x:i16,
	y:i16,
}
cell::struct{
	coords:[]point,
	character:[]rune,
	foreground: []string,
	background:[]string
}
