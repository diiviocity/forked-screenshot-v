module overlay

pub struct Pos {
pub mut:
	x int
	y int
}

pub struct Size {
pub mut:
	width  int
	height int
}

pub type Callback = fn (mut o Overlay)
