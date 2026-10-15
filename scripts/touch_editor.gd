extends CanvasLayer
## Full-screen editor for the touch buttons.
##   - drag a button to move it
##   - the panel changes the SIZE and OPACITY of the selected button, hides / shows it, resets it
##   - changes are applied live and saved when you press DONE (or BACK)
## Open it from OPTIONS > CONTROLS (with a sample background) or from the pause menu (over the game).

const BtnView = preload("res://scripts/touch_button_view.gd")
const SCREEN := Vector2(400, 224)

var with_backdrop := true
var on_close: Callable = Callable()

var _root: Control
var _panel: PanelContainer
var _name_l: Label
var _size_l: Label
var _alpha_l: Label
var _vis_btn: Button
var _done_btn: Button
var _views := {}
var _sel := "jump"
var _drag_id := ""
var _drag_ptr := -9
var _drag_off := Vector2.ZERO


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	TouchUI.editing = true
	TouchUI.release_all()
	_root = Control.new()
	_root.size = SCREEN
	_root.mouse_filter = Control.MOUSE_FILTER_STOP     # nothing underneath gets clicked
	add_child(_root)
	_build_backdrop()
	for id in TouchUI.IDS:
		var v := BtnView.new()
		v.id = id
		v.ghost = true
		_root.add_child(v)
		_views[id] = v
	_build_panel()
	_select(_sel)
	var hint := UI.label("DRAG A BUTTON TO MOVE IT", 8, Color(1, 1, 1, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 108)
	hint.size = Vector2(400, 12)
	hint.name = "Hint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hint)
	_refresh_all()
	_done_btn.call_deferred("grab_focus")
	call_deferred("_dock")


func _build_backdrop() -> void:
	if with_backdrop:
		var th: Dictionary = Game.LevelsData.THEMES["grass"]
		_root.add_child(Game.make_sky(th["sky_top"], th["sky_bot"]))
		var grass := ColorRect.new()
		grass.color = Color(0.36, 0.72, 0.26)
		grass.position = Vector2(0, 196)
		grass.size = Vector2(400, 6)
		grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(grass)
		var dirt := ColorRect.new()
		dirt.color = Color(0.55, 0.34, 0.16)
		dirt.position = Vector2(0, 202)
		dirt.size = Vector2(400, 22)
		dirt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(dirt)
	else:
		var dim := ColorRect.new()
		dim.color = Color(0.01, 0.01, 0.08, 0.55)
		dim.size = SCREEN
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(dim)


# ------------------------------------------------------------------ panel
func _stepper_row(text: String, on_minus: Callable, on_plus: Callable, out: Array) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	var l := UI.label(text, 8, Color(0.75, 0.85, 1.0))
	l.custom_minimum_size = Vector2(36, 17)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(l)
	hb.add_child(UI.compact_button("-", on_minus, 22))
	var v := UI.label("100%", 8, UI.GOLD)
	v.custom_minimum_size = Vector2(36, 17)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(v)
	hb.add_child(UI.compact_button("+", on_plus, 22))
	out.append(v)
	return hb


func _build_panel() -> void:
	_panel = UI.panel()
	var sb := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 5
	sb.content_margin_bottom = 7
	_panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_panel.add_child(vb)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	_name_l = UI.label("JUMP", 8, UI.MINT)
	_name_l.custom_minimum_size = Vector2(46, 17)
	_name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row1.add_child(_name_l)
	var outs: Array = []
	row1.add_child(_stepper_row("SIZE", func(): _bump_size(-0.1), func(): _bump_size(0.1), outs))
	row1.add_child(_stepper_row("OPAC", func(): _bump_alpha(-0.1), func(): _bump_alpha(0.1), outs))
	_size_l = outs[0]
	_alpha_l = outs[1]
	vb.add_child(row1)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 4)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	_vis_btn = UI.button("HIDE", _toggle_visible, 56)
	row2.add_child(_vis_btn)
	row2.add_child(UI.button("RESET", _reset_selected, 64))
	row2.add_child(UI.button("RESET ALL", _reset_all, 96))
	_done_btn = UI.button("DONE", close, 64)
	row2.add_child(_done_btn)
	vb.add_child(row2)
	_root.add_child(_panel)


## The panel sits at the top, or at the bottom when the selected button is in the upper half.
func _dock() -> void:
	_panel.reset_size()
	var y := 3.0
	if TouchUI.center(_sel).y < SCREEN.y * 0.5:
		y = SCREEN.y - _panel.size.y - 3.0
	_panel.position = Vector2(roundf((SCREEN.x - _panel.size.x) * 0.5), y)


# ------------------------------------------------------------------ editing
func _select(id: String) -> void:
	_sel = id
	for k in _views:
		_views[k].selected = (k == id)
		_views[k].queue_redraw()
	_update_labels()


func _update_labels() -> void:
	var e: Dictionary = TouchUI.layout[_sel]
	_name_l.text = TouchUI.DEFS[_sel]["label"]
	_size_l.text = "%d%%" % int(roundf(float(e["s"]) * 100.0))
	_alpha_l.text = "%d%%" % int(roundf(float(e["a"]) * 100.0))
	_vis_btn.text = "HIDE" if bool(e["v"]) else "SHOW"


func _refresh_all() -> void:
	for id in TouchUI.IDS:
		var v: Control = _views[id]
		v.ghost = not TouchUI.is_on(id)
		v.refresh()
		v.visible = true
	_update_labels()


func _bump_size(d: float) -> void:
	var e: Dictionary = TouchUI.layout[_sel]
	e["s"] = clampf(snappedf(float(e["s"]) + d, 0.05), TouchUI.SCALE_MIN, TouchUI.SCALE_MAX)
	_refresh_all()
	_dock()


func _bump_alpha(d: float) -> void:
	var e: Dictionary = TouchUI.layout[_sel]
	e["a"] = clampf(snappedf(float(e["a"]) + d, 0.05), TouchUI.ALPHA_MIN, 1.0)
	_refresh_all()


func _toggle_visible() -> void:
	var e: Dictionary = TouchUI.layout[_sel]
	e["v"] = not bool(e["v"])
	_refresh_all()


func _reset_selected() -> void:
	TouchUI.reset_button(_sel)
	_refresh_all()
	_dock()


func _reset_all() -> void:
	TouchUI.reset_layout()
	_refresh_all()
	_dock()


func close() -> void:
	TouchUI.editing = false
	TouchUI.save()
	TouchUI.refresh_views()
	if on_close.is_valid():
		on_close.call()
	queue_free()


# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
		return
	var real_touch := DisplayServer.is_touchscreen_available()
	if event is InputEventScreenTouch:
		_pointer(event.index, event.position, event.pressed, false)
	elif event is InputEventScreenDrag:
		_pointer(event.index, event.position, true, true)
	elif not real_touch and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer(0, event.position, event.pressed, false)
	elif not real_touch and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_pointer(0, event.position, true, true)


func _pointer(idx: int, pos: Vector2, pressed: bool, is_drag: bool) -> void:
	if pressed and not is_drag:
		if _panel.get_rect().has_point(pos):
			return
		var id := TouchUI.hit(pos, true)
		if id == "":
			return
		_select(id)
		_drag_id = id
		_drag_ptr = idx
		_drag_off = TouchUI.center(id) - pos
		get_viewport().set_input_as_handled()
	elif is_drag and idx == _drag_ptr and _drag_id != "":
		TouchUI.set_center(_drag_id, pos + _drag_off)
		_views[_drag_id].refresh()
		_views[_drag_id].visible = true
		get_viewport().set_input_as_handled()
	elif not pressed and idx == _drag_ptr:
		_drag_id = ""
		_drag_ptr = -9
		TouchUI.save()
		_dock()
