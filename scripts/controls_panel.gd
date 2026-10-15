extends VBoxContainer
## Rebinding screen for the OPTIONS menu with two separate tabs: KEYBOARD and CONTROLLER.
## Click (or press A / Enter on) a slot, then press the new key / button.
##   Keyboard tab:   ESC = cancel, DEL / BACKSPACE = clear the slot
##   Controller tab: BACK / SELECT = clear the slot, cancels by itself after a few seconds
## A binding already used elsewhere in the same tab is swapped, and every action keeps at least one.
## Stick / D-pad movement and menu navigation (A/X select, B back) are fixed on purpose.

const IDLE_KEY := "CLICK A KEY TO CHANGE IT"
const LISTEN_KEY := "PRESS KEY  ESC=CANCEL  DEL=CLEAR"
const IDLE_PAD := "CLICK A SLOT, PRESS A BUTTON"
const LISTEN_PAD := "PRESS BUTTON  BACK=CLEAR"
const HINT_COLOR := Color(0.75, 0.85, 1.0)
const ERROR_COLOR := Color(1.0, 0.55, 0.5)
const LISTEN_TIMEOUT := 6.0

var _tab := 0  # 0 = keyboard, 1 = controller
var _btns := {}
var _tab_btns: Array = []
var _pages: Array = []
var _hint: Label
var _reset_btn: Button
var _listen_action := ""
var _listen_slot := -1
var _listen_id := 0
var _listen_t := 0


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	# --- tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	for i in 2:
		var idx: int = i
		var tb := UI.compact_button("", func(): _set_tab(idx), 136)
		tabs.add_child(tb)
		_tab_btns.append(tb)
	add_child(tabs)
	# --- keyboard page
	var kb := VBoxContainer.new()
	kb.add_theme_constant_override("separation", 2)
	for def in Game.REBINDABLE:
		kb.add_child(_make_row(false, def["id"], def["label"]))
	add_child(kb)
	_pages.append(kb)
	# --- controller page (same height as the keyboard page so the panel never jumps)
	var pd := VBoxContainer.new()
	pd.add_theme_constant_override("separation", 2)
	for def in Game.REBINDABLE_PAD:
		pd.add_child(_make_row(true, def["id"], def["label"]))
	pd.add_child(_info_row("MOVE", "STICK / D-PAD"))
	pd.add_child(_info_row("MENU", "A/X OK  B BACK"))
	add_child(pd)
	_pages.append(pd)
	# --- shared footer
	_hint = UI.label(IDLE_KEY, 8, HINT_COLOR)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_reset_btn = UI.button("RESET KEYBOARD", _on_reset, 276)
	add_child(_reset_btn)
	_set_tab(0)


## Explicit focus layout (no geometric guessing): from a tab, LEFT / RIGHT only switches between the
## two tabs and DOWN enters the list at its FIRST slot; inside the list every move is one cell;
## UP from the first row returns to the active tab. Re-done whenever the tab changes.
func _wire(t: int) -> void:
	var rows: Array = [[_tab_btns[0], _tab_btns[1]]]
	var defs: Array = Game.REBINDABLE if t == 0 else Game.REBINDABLE_PAD
	for def in defs:
		var row: Array = []
		for s in Game.KEY_SLOTS:
			row.append(_btns[_key(t == 1, def["id"], s)])
		rows.append(row)
	rows.append([_reset_btn])
	UI.wire_focus_grid(rows)
	var first_slot: Control = rows[1][0]
	for tb in _tab_btns:
		tb.focus_neighbor_bottom = tb.get_path_to(first_slot)
	for b in rows[1]:
		b.focus_neighbor_top = b.get_path_to(_tab_btns[t])
	# below RESET comes the BACK button of the panel: let Godot find it
	_reset_btn.focus_neighbor_bottom = NodePath()


func focus_first() -> void:
	var first: Button = _btns[_key(false, Game.REBINDABLE[0]["id"], 0)]
	first.grab_focus()


func _key(pad: bool, action: String, slot: int) -> String:
	return "%s:%s:%d" % ["p" if pad else "k", action, slot]


func _make_row(pad: bool, action: String, label_text: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	var l := UI.label(label_text, 8, Color.WHITE)
	l.custom_minimum_size = Vector2(84, 17)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(l)
	for s in Game.KEY_SLOTS:
		var slot: int = s
		var b := UI.compact_button("", func(): _start_listen(action, slot), 60)
		hb.add_child(b)
		_btns[_key(pad, action, slot)] = b
	return hb


func _info_row(label_text: String, value: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	var l := UI.label(label_text, 8, Color(0.6, 0.65, 0.8))
	l.custom_minimum_size = Vector2(84, 17)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(l)
	var v := UI.label(value, 8, Color(0.6, 0.65, 0.8))
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(v)
	return hb


func _set_tab(t: int) -> void:
	_tab = t
	_stop_listen()
	for i in 2:
		_pages[i].visible = (i == t)
	_tab_btns[0].text = "[KEYBOARD]" if t == 0 else "KEYBOARD"
	_tab_btns[1].text = "[CONTROLLER]" if t == 1 else "CONTROLLER"
	_reset_btn.text = "RESET KEYBOARD" if t == 0 else "RESET CONTROLLER"
	_set_hint(IDLE_KEY if t == 0 else IDLE_PAD, HINT_COLOR)
	_refresh()
	_wire(t)


func _refresh() -> void:
	for def in Game.REBINDABLE:
		_refresh_row(false, def["id"])
	for def in Game.REBINDABLE_PAD:
		_refresh_row(true, def["id"])


func _refresh_row(pad: bool, a: String) -> void:
	for s in Game.KEY_SLOTS:
		var b: Button = _btns[_key(pad, a, s)]
		var listening: bool = (a == _listen_action and s == _listen_slot and pad == (_tab == 1))
		if listening:
			b.text = "PRESS!"
			b.add_theme_color_override("font_color", UI.GOLD)
		else:
			if pad:
				b.text = Game.pad_text(int(Game.pad_binds[a][s]))
			else:
				b.text = Game.key_text(int(Game.key_binds[a][s]))
			b.remove_theme_color_override("font_color")


func _idle_hint() -> String:
	return IDLE_KEY if _tab == 0 else IDLE_PAD


func _set_hint(text: String, color: Color) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", color)


func _hint_later() -> void:
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(func():
		if _listen_action == "":
			_set_hint(_idle_hint(), HINT_COLOR))


func _start_listen(action: String, slot: int) -> void:
	_listen_action = action
	_listen_slot = slot
	_listen_t = Time.get_ticks_msec()
	_listen_id += 1
	_set_hint(LISTEN_KEY if _tab == 0 else LISTEN_PAD, UI.GOLD)
	_refresh()
	if _tab == 1:
		# controller-only players have no ESC: cancel automatically
		var my_id := _listen_id
		var tw := create_tween()
		tw.tween_interval(LISTEN_TIMEOUT)
		tw.tween_callback(func():
			if _listen_id == my_id and _listen_action != "":
				_stop_listen())


func _stop_listen() -> void:
	_listen_action = ""
	_listen_slot = -1
	_listen_id += 1
	if _hint != null:
		_set_hint(_idle_hint(), HINT_COLOR)
		_refresh()


func _finish(err: String) -> void:
	_listen_action = ""
	_listen_slot = -1
	_listen_id += 1
	if err == "":
		Audio.play("select")
		_set_hint(_idle_hint(), HINT_COLOR)
	else:
		Audio.play("click")
		_set_hint(err, ERROR_COLOR)
		_hint_later()
	_refresh()


func _on_reset() -> void:
	_listen_action = ""
	_listen_slot = -1
	_listen_id += 1
	if _tab == 0:
		Game.reset_binds()
		_set_hint("DEFAULT KEYS RESTORED!", UI.MINT)
	else:
		Game.reset_pad_binds()
		_set_hint("DEFAULT BUTTONS RESTORED!", UI.MINT)
	_refresh()
	_hint_later()


## Runs before the GUI and the menu's own handlers, so whatever is pressed while listening is
## captured here and never triggers pause / button presses.
func _input(event: InputEvent) -> void:
	if _listen_action == "":
		return
	if event is InputEventMouseButton and event.pressed:
		_stop_listen()
		return
	if Time.get_ticks_msec() - _listen_t < 150 and not (event is InputEventMouseMotion):
		if event is InputEventKey or event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()
		return
	if _tab == 0:
		_input_keyboard(event)
	else:
		_input_pad(event)


func _input_keyboard(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_stop_listen()
		get_viewport().set_input_as_handled()
		return
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return
	get_viewport().set_input_as_handled()
	var code: int = int(ke.physical_keycode)
	if code == 0:
		code = int(ke.keycode)
	if code == KEY_ESCAPE:
		_stop_listen()
		return
	if code == KEY_DELETE or code == KEY_BACKSPACE:
		code = 0
	_finish(Game.try_bind(_listen_action, _listen_slot, code))


func _input_pad(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke != null:
		if ke.pressed and not ke.echo:
			get_viewport().set_input_as_handled()
			if ke.physical_keycode == KEY_ESCAPE:
				_stop_listen()
			elif ke.physical_keycode == KEY_DELETE or ke.physical_keycode == KEY_BACKSPACE:
				_finish(Game.try_pad_bind(_listen_action, _listen_slot, Game.PAD_EMPTY))
		return
	var jb := event as InputEventJoypadButton
	if jb != null and jb.pressed:
		get_viewport().set_input_as_handled()
		var code: int = int(jb.button_index)
		if code == JOY_BUTTON_BACK:
			code = Game.PAD_EMPTY
		_finish(Game.try_pad_bind(_listen_action, _listen_slot, code))
		return
	var jm := event as InputEventJoypadMotion
	if jm != null:
		var ax: int = int(jm.axis)
		if (ax == JOY_AXIS_TRIGGER_LEFT or ax == JOY_AXIS_TRIGGER_RIGHT) and jm.axis_value > 0.6:
			get_viewport().set_input_as_handled()
			_finish(Game.try_pad_bind(_listen_action, _listen_slot, Game.PAD_AXIS_BASE + ax))
