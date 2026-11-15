module overlay

import wayland
import wayland.protocols.wayland as wl
import wayland.protocols.wlr_layer_shell_unstable_v1 as layer_shell
import math

// structs
pub struct Overlay {
pub:
	conn    &wayland.Connection
	buffer  &wayland.ShmBuffer
	surface wl.WlSurface
pub mut:
	layerlistener    &LayerListener
	keyboardlistener &KeyboardListener
	pointer          &wayland.Pointer

	box_pos  Pos
	box_size Size

	bindings map[string]Callback
	running  bool
}

pub fn (o Overlay) draw_pixels(pos Pos, size Size, color string) {
	mut pixels := o.buffer.pixels()

	r := '0x${color[1..3]}'.u8()
	g := '0x${color[3..5]}'.u8()
	b := '0x${color[5..7]}'.u8()
	a := 0xff
	for x in pos.x .. pos.x + size.width {
		for y in pos.y .. pos.y + size.height {
			if x < 0 || y < 0 || x >= o.buffer.width || y >= o.buffer.height {
				continue
			}
			offset := y * o.buffer.stride + x * 4

			pixels[offset] = b
			pixels[offset + 1] = g
			pixels[offset + 2] = r
			pixels[offset + 3] = a
		}
	}
}

pub fn (mut o Overlay) draw_box(thickness int) {
	// top
	o.draw_pixels(o.box_pos, overlay.Size{
		width:  o.box_size.width
		height: thickness
	}, '#89b4fa')

	// bottom
	o.draw_pixels(overlay.Pos{
		x: o.box_pos.x
		y: o.box_pos.y + o.box_size.height - thickness
	}, overlay.Size{
		width:  o.box_size.width
		height: thickness
	}, '#89b4fa')

	// left
	o.draw_pixels(o.box_pos, overlay.Size{
		width:  thickness
		height: o.box_size.height
	}, '#89b4fa')

	// right
	o.draw_pixels(overlay.Pos{
		x: o.box_pos.x + o.box_size.width - thickness
		y: o.box_pos.y
	}, overlay.Size{
		width:  thickness
		height: o.box_size.height
	}, '#89b4fa')
}

pub fn (mut o Overlay) bind_input(name string, cb Callback) {
	o.bindings[name] = cb
}

pub fn (mut o Overlay) clear() {
	mut pixels := o.buffer.pixels()
	unsafe { vmemset(pixels.data, 0, pixels.len) }
}

pub fn (mut o Overlay) redraw() ! {
	o.clear()
	o.draw_box(2)
	o.buffer.attach(o.surface)!
	o.surface.commit()!
}

pub fn (mut o Overlay) stop() {
	o.running = false
}

// functions
pub fn (mut o Overlay) run() ! {
	o.redraw()!

	o.running = true
	for o.running {
		o.conn.dispatch()!

		if o.keyboardlistener.pressed != '' {
			if cb := o.bindings[o.keyboardlistener.pressed] {
				cb(mut o)
			}
			o.keyboardlistener.pressed = ''
		}

		if m := o.pointer.take_motion() {
			if o.pointer.pressed(wayland.btn_left) {
				o.box_pos.x += m.dx
				o.box_pos.y += m.dy
			}
			if o.pointer.pressed(wayland.btn_right) {
				o.box_size.width = math.max(o.box_size.width + m.dx, 10)
				o.box_size.height = math.max(o.box_size.height + m.dy, 10)
			}
			if o.pointer.pressed(wayland.btn_left) || o.pointer.pressed(wayland.btn_right) {
				o.redraw()!
			}
		}
	}
}

pub fn (mut o Overlay) close() ! {
	o.buffer.destroy()
	o.conn.close()
}

pub fn new() !Overlay {
	mut conn := wayland.connect()!
	globals := conn.globals()!

	// finding & binding
	compositor := wl.bind_wl_compositor(conn, find_global(globals, 'wl_compositor')!)!
	shm := wl.bind_wl_shm(conn, find_global(globals, 'wl_shm')!)!
	shell := layer_shell.bind_zwlr_layer_shell_v1(conn, find_global(globals, 'zwlr_layer_shell_v1')!)!
	seat := wl.bind_wl_seat(conn, find_global(globals, 'wl_seat')!)!

	surface := compositor.create_surface()!
	layer := shell.get_layer_surface(surface, none, layer_shell.zwlr_layer_shell_v1_layer_overlay, 'screenshot!')!
	keyboard := seat.get_keyboard()!
	pointer := wayland.Pointer.new(compositor, seat)!

	// listeners
	mut layerlistener := &LayerListener{}
	layer.set_listener(layerlistener)!

	mut keyboardlistener := &KeyboardListener{}
	keyboard.set_listener(keyboardlistener)!

	// rendering
	layer.set_size(0, 0)!

	anchors := layer_shell.zwlr_layer_surface_v1_anchor_top | layer_shell.zwlr_layer_surface_v1_anchor_bottom | layer_shell.zwlr_layer_surface_v1_anchor_left | layer_shell.zwlr_layer_surface_v1_anchor_right
	layer.set_anchor(anchors)!
	layer.set_exclusive_zone(-1)!
	layer.set_keyboard_interactivity(layer_shell.zwlr_layer_surface_v1_keyboard_interactivity_exclusive)!
	surface.commit()!
	for !layerlistener.configured {
		conn.roundtrip()!
	}

	println('screen size: x=${layerlistener.width}, y=${layerlistener.height}')

	layer.ack_configure(layerlistener.serial)!
	mut buffer := wayland.ShmBuffer.new(shm, int(layerlistener.width), int(layerlistener.height), wl.wl_shm_format_argb8888)!

	return Overlay{
		buffer:           buffer
		surface:          surface
		conn:             conn
		layerlistener:    layerlistener
		keyboardlistener: keyboardlistener
		pointer:          pointer
	}
}

fn find_global(globals []wayland.Global, name string) !wayland.Global {
	return globals.find(name) or { return error('no ${name}') }
}
