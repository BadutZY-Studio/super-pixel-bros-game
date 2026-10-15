extends VBoxContainer
## OPTIONS > CONTROLS: settings of the on-screen touch buttons.
## (The old keyboard / controller rebinding is gone: a keyboard or gamepad that is plugged in
## simply works with fixed keys, see game.gd.)

const TouchEditor = preload("res://scripts/touch_editor.gd")
const W := 276.0

var _mode_btn: Button
var _edit_btn: Button
var _vals := {}


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	_mode_btn = UI.button("", func():
		TouchUI.mode = (TouchUI.mode + 1) % 3
		TouchUI.save()
		_refresh(), W)
	add_child(_mode_btn)
	var r_op := _stepper("ALL OPACITY", "op")
	var r_sz := _stepper("ALL SIZE", "sz")
	add_child(r_op[0])
	add_child(r_sz[0])
	var t1 := UI.toggle("VIBRATION", func(): return TouchUI.haptic, func(on: bool):
		TouchUI.haptic = on
		TouchUI.save(), W)
	var t2 := UI.toggle("AUTO RUN", func(): return TouchUI.auto_run, func(on: bool):
		TouchUI.auto_run = on
		TouchUI.save(), W)
	var t3 := UI.toggle("HIDE IF PAD", func(): return TouchUI.hide_with_pad, func(on: bool):
		TouchUI.hide_with_pad = on
		TouchUI.save(), W)
	add_child(t1)
	add_child(t2)
	add_child(t3)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	_edit_btn = UI.button("EDIT BUTTONS", _open_editor, 164)
	var reset_btn := UI.button("RESET", func():
		TouchUI.reset_layout()
		TouchUI.g_opacity = 1.0
		TouchUI.g_size = 1.0
		TouchUI.save()
		_refresh(), 108)
	hb.add_child(_edit_btn)
	hb.add_child(reset_btn)
	add_child(hb)
	var rows: Array = [[_mode_btn], [r_op[1], r_op[2]], [r_sz[1], r_sz[2]], [t1], [t2], [t3], [_edit_btn, reset_btn]]
	UI.wire_focus_grid(rows)
	_refresh()


func focus_first() -> void:
	_mode_btn.grab_focus()


## Row: label  [-]  value  [+]. Returns [row, minus_button, plus_button].
func _stepper(text: String, key: String) -> Array:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	var l := UI.label(text, 8, Color.WHITE)
	l.custom_minimum_size = Vector2(160, 17)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 2)
	hb.add_child(l)
	var minus := UI.compact_button("-", func(): _step(key, -0.1), 28)
	var v := UI.label("100%", 8, UI.GOLD)
	v.custom_minimum_size = Vector2(48, 17)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var plus := UI.compact_button("+", func(): _step(key, 0.1), 28)
	hb.add_child(minus)
	hb.add_child(v)
	hb.add_child(plus)
	_vals[key] = v
	return [hb, minus, plus]


func _step(key: String, d: float) -> void:
	if key == "op":
		TouchUI.g_opacity = clampf(snappedf(TouchUI.g_opacity + d, 0.1), 0.1, 1.0)
	else:
		TouchUI.g_size = clampf(snappedf(TouchUI.g_size + d, 0.1), TouchUI.GLOBAL_MIN, TouchUI.GLOBAL_MAX)
	TouchUI.save()
	_refresh()


func _refresh() -> void:
	_mode_btn.text = "TOUCH BUTTONS: " + TouchUI.MODE_NAMES[TouchUI.mode]
	(_vals["op"] as Label).text = "%d%%" % int(roundf(TouchUI.g_opacity * 100.0))
	(_vals["sz"] as Label).text = "%d%%" % int(roundf(TouchUI.g_size * 100.0))
	TouchUI.refresh_views()


func _open_editor() -> void:
	var ed := TouchEditor.new()
	ed.with_backdrop = true
	ed.on_close = func():
		_refresh()
		if is_instance_valid(_edit_btn):
			_edit_btn.grab_focus()
	get_tree().root.add_child(ed)
