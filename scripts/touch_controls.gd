extends CanvasLayer
## On-screen touch controls (autoload "TouchUI").
##
## Seven round buttons are drawn over the level: LEFT, RIGHT, DOWN, JUMP, RUN, FIRE and PAUSE.
## Every button can be moved, resized, made more / less transparent or hidden (see
## touch_editor.gd) and the layout is saved with the rest of the game.
##
## The buttons feed the normal input actions, so the player script needs no special code:
##   LEFT / RIGHT -> "left" / "right"      DOWN -> "down" (enter a warp pipe)
##   JUMP -> "jump"      PAUSE -> "pause"
##   RUN  -> "dash"  (run only)            FIRE -> "fire"      (fireball only)
## A keyboard / gamepad plugged into the phone still works at the same time.
##
## Multi-touch: every finger is tracked on its own, and sliding a finger from LEFT to RIGHT
## (or onto any other button) switches the pressed button without lifting it.

const BtnView = preload("res://scripts/touch_button_view.gd")

const SCREEN := Vector2(400, 224)
const IDS := ["left", "right", "down", "jump", "run", "fire", "pause"]
const DEFS := {
	"left": {"label": "LEFT", "action": "left", "pos": Vector2(36, 190), "size": 40.0, "color": Color(0.30, 0.45, 0.95)},
	"right": {"label": "RIGHT", "action": "right", "pos": Vector2(88, 190), "size": 40.0, "color": Color(0.30, 0.45, 0.95)},
	"down": {"label": "DOWN", "action": "down", "pos": Vector2(62, 150), "size": 34.0, "color": Color(0.20, 0.70, 0.45)},
	"jump": {"label": "JUMP", "action": "jump", "pos": Vector2(366, 188), "size": 46.0, "color": Color(0.93, 0.27, 0.22)},
	"run": {"label": "RUN", "action": "dash", "pos": Vector2(314, 200), "size": 38.0, "color": Color(0.95, 0.75, 0.15)},
	"fire": {"label": "FIRE", "action": "fire", "pos": Vector2(330, 146), "size": 38.0, "color": Color(1.0, 0.50, 0.12)},
	"pause": {"label": "PAUSE", "action": "pause", "pos": Vector2(378, 42), "size": 22.0, "color": Color(0.55, 0.60, 0.72)},
}
const SCALE_MIN := 0.5
const SCALE_MAX := 1.8
const ALPHA_MIN := 0.1
const GLOBAL_MIN := 0.5
const GLOBAL_MAX := 1.5
const MODE_NAMES := ["AUTO", "ALWAYS ON", "OFF"]

var mode := 0                 # 0 = auto (touchscreen devices), 1 = always show, 2 = never show
var g_opacity := 1.0          # multiplier on every button's own opacity
var g_size := 1.0             # multiplier on every button's own size
var haptic := true            # short vibration on press (Android)
var auto_run := false         # hold RUN permanently while the touch buttons are on screen
var hide_with_pad := false    # AUTO mode: hide the buttons while a gamepad is connected
var layout := {}              # id -> {x, y, s (size), a (opacity), v (visible)}

var shown := false            # true while the buttons are on screen and reacting
var editing := false          # true while the layout editor is open

var _pad: Control
var _views := {}
var _down := {}               # id -> true while that button is held
var _ptr := {}                # finger index -> button id ("" = finger is on nothing)


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_layout()
	from_dict(Game.touch_saved)
	_pad = Control.new()
	_pad.size = SCREEN
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.visible = false
	add_child(_pad)
	for id in IDS:
		var v := BtnView.new()
		v.id = id
		_pad.add_child(v)
		_views[id] = v
	refresh_views()


# ------------------------------------------------------------------ layout data
func default_entry(id: String) -> Dictionary:
	var p: Vector2 = DEFS[id]["pos"]
	return {"x": p.x, "y": p.y, "s": 1.0, "a": 0.7, "v": true}


func reset_layout() -> void:
	layout = {}
	for id in IDS:
		layout[id] = default_entry(id)


func reset_button(id: String) -> void:
	layout[id] = default_entry(id)


func radius(id: String) -> float:
	return float(DEFS[id]["size"]) * 0.5 * float(layout[id]["s"]) * g_size


func center(id: String) -> Vector2:
	var r := radius(id)
	var e: Dictionary = layout[id]
	return Vector2(clampf(float(e["x"]), r, SCREEN.x - r), clampf(float(e["y"]), r, SCREEN.y - r))


func set_center(id: String, p: Vector2) -> void:
	var r := radius(id)
	layout[id]["x"] = clampf(p.x, r, SCREEN.x - r)
	layout[id]["y"] = clampf(p.y, r, SCREEN.y - r)


func alpha(id: String) -> float:
	return clampf(float(layout[id]["a"]) * g_opacity, 0.05, 1.0)


func is_on(id: String) -> bool:
	return bool(layout[id]["v"])


func to_dict() -> Dictionary:
	return {"mode": mode, "opacity": g_opacity, "size": g_size, "haptic": haptic,
		"auto_run": auto_run, "hide_pad": hide_with_pad, "layout": layout}


func from_dict(d) -> void:
	if typeof(d) != TYPE_DICTIONARY:
		return
	mode = clampi(int(d.get("mode", 0)), 0, 2)
	g_opacity = clampf(float(d.get("opacity", 1.0)), GLOBAL_MIN * 0.2, 1.0)
	g_size = clampf(float(d.get("size", 1.0)), GLOBAL_MIN, GLOBAL_MAX)
	haptic = bool(d.get("haptic", true))
	auto_run = bool(d.get("auto_run", false))
	hide_with_pad = bool(d.get("hide_pad", false))
	var lay = d.get("layout", {})
	if typeof(lay) == TYPE_DICTIONARY:
		for id in IDS:
			if lay.has(id) and typeof(lay[id]) == TYPE_DICTIONARY:
				var src: Dictionary = lay[id]
				var e := default_entry(id)
				e["x"] = clampf(float(src.get("x", e["x"])), 0.0, SCREEN.x)
				e["y"] = clampf(float(src.get("y", e["y"])), 0.0, SCREEN.y)
				e["s"] = clampf(float(src.get("s", 1.0)), SCALE_MIN, SCALE_MAX)
				e["a"] = clampf(float(src.get("a", 0.7)), ALPHA_MIN, 1.0)
				e["v"] = bool(src.get("v", true))
				layout[id] = e


func save() -> void:
	Game.save_game()


func refresh_views() -> void:
	for id in IDS:
		var v: Control = _views.get(id)
		if v != null:
			v.refresh()


# ------------------------------------------------------------------ visibility
func wants_touch() -> bool:
	if mode == 2:
		return false
	if mode == 1:
		return true
	if not DisplayServer.is_touchscreen_available():
		return false
	if hide_with_pad and not Input.get_connected_joypads().is_empty():
		return false
	return true


func _process(_delta: float) -> void:
	var want := false
	if not editing and wants_touch():
		var scn := get_tree().current_scene
		if scn != null and scn.has_method("touch_active") and scn.touch_active():
			want = true
	if want != shown:
		shown = want
		_pad.visible = shown
		if shown:
			refresh_views()
		else:
			release_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all()


# ------------------------------------------------------------------ hit testing
## Finds the button under a point (nearest centre wins). Hidden buttons only count in the editor.
func hit(pos: Vector2, include_hidden: bool = false) -> String:
	var best := ""
	var best_d := 1e9
	for id in IDS:
		if not include_hidden and not is_on(id):
			continue
		var d := center(id).distance_to(pos)
		if d <= radius(id) * 1.2 + 2.0 and d < best_d:
			best = id
			best_d = d
	return best


# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if not shown:
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
	if pressed:
		var id := hit(pos)
		if not is_drag and id == "":
			return                       # the finger landed on empty space: not ours
		if is_drag and not _ptr.has(idx):
			return
		_ptr[idx] = id
		get_viewport().set_input_as_handled()
	else:
		if not _ptr.has(idx):
			return
		_ptr.erase(idx)
	_sync()


func _sync() -> void:
	var want := {}
	for idx in _ptr:
		if _ptr[idx] != "":
			want[_ptr[idx]] = true
	for id in IDS:
		if want.has(id) and not _down.has(id):
			_press(id)
		elif not want.has(id) and _down.has(id):
			_release(id)


func _press(id: String) -> void:
	_down[id] = true
	_send(DEFS[id]["action"], true)
	if haptic and OS.has_feature("mobile"):
		Input.vibrate_handheld(18)
	_set_pressed(id, true)


func _release(id: String) -> void:
	_down.erase(id)
	_send(DEFS[id]["action"], false)
	_set_pressed(id, false)


func _set_pressed(id: String, p: bool) -> void:
	var v: Control = _views.get(id)
	if v != null:
		v.pressed = p
		v.queue_redraw()


func release_all() -> void:
	for id in _down.keys():
		_release(id)
	_ptr.clear()


func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)
