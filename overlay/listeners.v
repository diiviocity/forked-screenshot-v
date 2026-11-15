module overlay

import os
import wayland.protocols.wayland as wl
import wayland.protocols.wlr_layer_shell_unstable_v1 as layer_shell

//  [[ LAYER_LISTENER ]]
struct LayerListener {
mut:
	serial     u32
	width      u32
	height     u32
	configured bool
}

fn (mut l LayerListener) configure(_ layer_shell.ZwlrLayerSurfaceV1, serial u32, width u32, height u32) {
	l.serial = serial
	l.width = width
	l.height = height
	l.configured = true
}

fn (mut l LayerListener) closed(_ layer_shell.ZwlrLayerSurfaceV1) {}

//   [[ KEYBOARD_LISTENER ]]
struct KeyboardListener {
mut:
	ctrl    bool
	pressed string
}

fn (mut k KeyboardListener) keymap(_ wl.WlKeyboard, _format u32, fd int, _size u32) {
	os.fd_close(fd)
}

fn (mut k KeyboardListener) enter(_ wl.WlKeyboard, _serial u32, _surface wl.WlSurface, _keys []u8) {}

fn (mut k KeyboardListener) leave(_ wl.WlKeyboard, _serial u32, _surface wl.WlSurface) {}

fn (mut k KeyboardListener) key(_ wl.WlKeyboard, _serial u32, _time u32, key u32, state u32) {
	// ctrl logic
	if key == 29 || key == 97 {
		k.ctrl = state == 1
	}

	// letter logic
	if state != 1 { return }
	letters := match key {
		31 { 's' }
		46 { 'c' }
		1 { 'esc' }
		else { '' }
	}
	if letters == '' { return }

	// ctrl & letter connection
	name := if k.ctrl { 'ctrl+${letters}' } else { letters }

	k.pressed = name
}

fn (mut k KeyboardListener) modifiers(_ wl.WlKeyboard, _serial u32, _mods_depressed u32, _mods_latched u32, _mods_locked u32, _group u32) {}

fn (mut k KeyboardListener) repeat_info(_ wl.WlKeyboard, _rate i32, _delay i32) {}
