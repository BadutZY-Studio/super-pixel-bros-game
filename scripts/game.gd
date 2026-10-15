extends Node
## Global game state, save data, input map and small helpers (autoload "Game").

const LevelsData = preload("res://scripts/levels_data.gd")
const Cosmetics = preload("res://scripts/cosmetics.gd")
const SAVE_PATH := "user://super_pixel_bros.json"

## Chapters: 10 levels each. Level indices 0-9 = chapter 1, 10-19 = chapter 2.
const CHAPTERS := [
	{"name": "CHAPTER 1", "first": 0, "count": 10},
	{"name": "CHAPTER 2", "first": 10, "count": 10},
]

## Shop coins given for every course clear (set to 0 to only earn coins you pick up).
const CLEAR_BONUS := 10

var unlocked := 1
var best_scores := {}
var music_volume := 0.7
var sfx_volume := 0.9
var fullscreen := false

# --- rebindable keyboard controls (gamepad stays fixed)
const KEY_SLOTS := 3
const REBINDABLE := [
	{"id": "left", "label": "MOVE LEFT"},
	{"id": "right", "label": "MOVE RIGHT"},
	{"id": "jump", "label": "JUMP"},
	{"id": "run", "label": "RUN / FIRE"},
	{"id": "pause", "label": "PAUSE"},
]
const DEFAULT_KEYS := {
	"left": [KEY_LEFT, KEY_A, 0],
	"right": [KEY_RIGHT, KEY_D, 0],
	"jump": [KEY_SPACE, KEY_Z, KEY_UP],
	"run": [KEY_SHIFT, KEY_X, 0],
	"pause": [KEY_ESCAPE, KEY_P, 0],
}
const KEY_SHORT := {
	"ESCAPE": "ESC", "BACKSPACE": "BKSP", "PAGE DOWN": "PGDN", "PAGE UP": "PGUP",
	"CONTROL": "CTRL", "INSERT": "INS", "DELETE": "DEL", "CAPSLOCK": "CAPS",
}
var key_binds := {}

# --- rebindable gamepad buttons (stick / D-pad movement and menu navigation stay fixed)
# A code is a JoyButton index (0..), or PAD_AXIS_BASE + axis for the triggers, or PAD_EMPTY.
const PAD_EMPTY := -1
const PAD_AXIS_BASE := 100
const REBINDABLE_PAD := [
	{"id": "jump", "label": "JUMP"},
	{"id": "run", "label": "RUN / FIRE"},
	{"id": "pause", "label": "PAUSE"},
]
const DEFAULT_PAD := {
	"jump": [JOY_BUTTON_A, JOY_BUTTON_Y, -1],
	"run": [JOY_BUTTON_X, JOY_BUTTON_B, 105],
	"pause": [JOY_BUTTON_START, -1, -1],
}
const PAD_NAMES := {
	"xbox": {0: "A", 1: "B", 2: "X", 3: "Y", 4: "BACK", 5: "GUIDE", 6: "START", 7: "L3", 8: "R3",
		9: "LB", 10: "RB", 11: "UP", 12: "DOWN", 13: "LEFT", 14: "RIGHT", 104: "LT", 105: "RT"},
	"ps": {0: "CROSS", 1: "CIRCLE", 2: "SQUARE", 3: "TRIANG", 4: "SHARE", 5: "PS", 6: "OPTION", 7: "L3", 8: "R3",
		9: "L1", 10: "R1", 11: "UP", 12: "DOWN", 13: "LEFT", 14: "RIGHT", 104: "L2", 105: "R2"},
	"nin": {0: "B", 1: "A", 2: "Y", 3: "X", 4: "-", 5: "HOME", 6: "+", 7: "L3", 8: "R3",
		9: "L", 10: "R", 11: "UP", 12: "DOWN", 13: "LEFT", 14: "RIGHT", 104: "ZL", 105: "ZR"},
}
var pad_binds := {}

# --- current run
var current_level := 0
var lives := 3
var score := 0
var coins := 0
var player_state := 0
var checkpoints := {}

# --- shop: persistent wallet, bought items and what the hero is wearing (all saved)
var wallet := 0                  # coins you can spend in the shop (never reset by a new run)
var run_earned := 0              # shop coins collected since the current run started (for the result screens)
var owned := {}                  # item id -> true
var loadout := {}                # slot -> item id ("" = nothing)
var _wallet_dirty := false

var _tex_cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_cosmetics()
	_setup_inputs()
	key_binds = default_binds()
	pad_binds = default_pad_binds()
	load_game()
	apply_settings()
	apply_keybinds()
	apply_padbinds()


# ------------------------------------------------------------------ input
func _setup_inputs() -> void:
	# rebindable actions get their keyboard events in apply_keybinds()
	for def in REBINDABLE:
		if not InputMap.has_action(def["id"]):
			InputMap.add_action(def["id"], 0.3)
	_key_action("down", [KEY_DOWN, KEY_S])
	_setup_controller()


## Gamepad layout. Fixed: stick / D-pad = move. Menus: stick / D-pad = move focus, A or X = select,
## B = back (added explicitly if missing so a controller always works in the UI).
## Jump / run / pause buttons are rebindable and applied by apply_padbinds().
func _setup_controller() -> void:
	_pad_button("left", JOY_BUTTON_DPAD_LEFT)
	_pad_button("right", JOY_BUTTON_DPAD_RIGHT)
	_pad_button("down", JOY_BUTTON_DPAD_DOWN)
	_pad_axis("left", JOY_AXIS_LEFT_X, -1.0)
	_pad_axis("right", JOY_AXIS_LEFT_X, 1.0)
	_pad_axis("down", JOY_AXIS_LEFT_Y, 1.0)
	_ensure_pad("ui_accept", JOY_BUTTON_A)
	_ensure_pad("ui_accept", JOY_BUTTON_X)
	_ensure_pad("ui_cancel", JOY_BUTTON_B)
	_ensure_pad("ui_up", JOY_BUTTON_DPAD_UP)
	_ensure_pad("ui_down", JOY_BUTTON_DPAD_DOWN)
	_ensure_pad("ui_left", JOY_BUTTON_DPAD_LEFT)
	_ensure_pad("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_ensure_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_ensure_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_ensure_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_ensure_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)


func _ensure_pad(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		var jb := e as InputEventJoypadButton
		if jb != null and int(jb.button_index) == button:
			return
	_pad_button(action, button)


func _ensure_axis(action: String, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		var jm := e as InputEventJoypadMotion
		if jm != null and int(jm.axis) == axis and signf(jm.axis_value) == signf(value):
			return
	_pad_axis(action, axis, value)


func _key_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)
	for k in keys:
		var ev := InputEventKey.new()
		ev.device = -1
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _pad_button(action: String, button: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = -1  # any controller (the default 0 would only match the first one)
	ev.button_index = button as JoyButton
	InputMap.action_add_event(action, ev)


func _pad_axis(action: String, axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = -1
	ev.axis = axis as JoyAxis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


# ------------------------------------------------------------------ controller focus
## If a menu is on screen but nothing is focused (e.g. after the mouse left a button),
## the first D-pad / A press gives focus back to the first usable button so the pad
## never gets "stuck".
func _unhandled_input(event: InputEvent) -> void:
	var jb := event as InputEventJoypadButton
	if jb == null or not jb.pressed:
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	for n in get_tree().root.find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		if b != null and not b.disabled and b.focus_mode != Control.FOCUS_NONE and b.is_visible_in_tree():
			b.grab_focus()
			get_viewport().set_input_as_handled()
			return


# ------------------------------------------------------------------ key rebinding
func default_binds() -> Dictionary:
	var d := {}
	for a in DEFAULT_KEYS:
		d[a] = (DEFAULT_KEYS[a] as Array).duplicate()
	return d


## Replaces the keyboard events of every rebindable action with key_binds (gamepad events are kept).
func apply_keybinds() -> void:
	for a in DEFAULT_KEYS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.3)
		for old_ev in InputMap.action_get_events(a):
			if old_ev is InputEventKey:
				InputMap.action_erase_event(a, old_ev)
		for k in key_binds[a]:
			if int(k) != 0:
				var new_ev := InputEventKey.new()
				new_ev.device = -1
				new_ev.physical_keycode = int(k) as Key
				InputMap.action_add_event(a, new_ev)


## Returns a copy of binds with `code` put in the slot (a code already used elsewhere is swapped),
## or null when an action would be left without any binding.
func _rebind(binds: Dictionary, action: String, slot: int, code: int, empty: int) -> Variant:
	var nb := {}
	for a in binds:
		nb[a] = (binds[a] as Array).duplicate()
	var old: int = int(nb[action][slot])
	if code != empty:
		for a in nb:
			for sl in KEY_SLOTS:
				if int(nb[a][sl]) == code and not (a == action and sl == slot):
					nb[a][sl] = old
	nb[action][slot] = code
	for a in nb:
		var has_one := false
		for sl in KEY_SLOTS:
			if int(nb[a][sl]) != empty:
				has_one = true
		if not has_one:
			return null
	return nb


## Binds keycode (0 = clear) to a keyboard slot. Returns "" on success or a short error message.
func try_bind(action: String, slot: int, keycode: int) -> String:
	var nb: Variant = _rebind(key_binds, action, slot, keycode, 0)
	if nb == null:
		return "NEED 1 KEY PER ACTION"
	key_binds = nb
	apply_keybinds()
	save_game()
	return ""


## Same for the gamepad (code = PAD_EMPTY clears the slot).
func try_pad_bind(action: String, slot: int, code: int) -> String:
	var nb: Variant = _rebind(pad_binds, action, slot, code, PAD_EMPTY)
	if nb == null:
		return "NEED 1 BUTTON PER ACTION"
	pad_binds = nb
	apply_padbinds()
	save_game()
	return ""


func reset_binds() -> void:
	key_binds = default_binds()
	apply_keybinds()
	save_game()


func default_pad_binds() -> Dictionary:
	var d := {}
	for a in DEFAULT_PAD:
		d[a] = (DEFAULT_PAD[a] as Array).duplicate()
	return d


func reset_pad_binds() -> void:
	pad_binds = default_pad_binds()
	apply_padbinds()
	save_game()


## Replaces the gamepad button / trigger events of the rebindable actions with pad_binds.
func apply_padbinds() -> void:
	for a in DEFAULT_PAD:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.3)
		for old_ev in InputMap.action_get_events(a):
			if old_ev is InputEventJoypadButton or old_ev is InputEventJoypadMotion:
				InputMap.action_erase_event(a, old_ev)
		for c in pad_binds[a]:
			var code := int(c)
			if code == PAD_EMPTY:
				continue
			if code >= PAD_AXIS_BASE:
				_pad_axis(a, code - PAD_AXIS_BASE, 1.0)
			else:
				_pad_button(a, code)


## "xbox", "ps" or "nin", guessed from the first connected controller (labels only).
func pad_style() -> String:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return "xbox"
	var n := Input.get_joy_name(int(pads[0])).to_lower()
	for w in ["playstation", "ps3", "ps4", "ps5", "dualshock", "dualsense", "sony"]:
		if n.contains(w):
			return "ps"
	for w in ["nintendo", "switch", "joy-con", "joycon"]:
		if n.contains(w):
			return "nin"
	return "xbox"


## Short display name (max 6 chars) of a gamepad code, "-" when empty.
func pad_text(code: int) -> String:
	if code == PAD_EMPTY:
		return "-"
	var names: Dictionary = PAD_NAMES[pad_style()]
	if names.has(code):
		return names[code]
	return "BTN%d" % code if code < PAD_AXIS_BASE else "AXIS%d" % (code - PAD_AXIS_BASE)


func pad_names(action: String) -> Array:
	var out: Array = []
	for c in pad_binds[action]:
		if int(c) != PAD_EMPTY:
			out.append(pad_text(int(c)))
	return out


## Short display name of a physical keycode (max 6 chars, "-" when empty).
func key_text(k: int) -> String:
	if k == 0:
		return "-"
	var code: int = int(DisplayServer.keyboard_get_keycode_from_physical(k as Key))
	if code == 0:
		code = k
	var t := OS.get_keycode_string(code as Key).to_upper()
	if KEY_SHORT.has(t):
		t = KEY_SHORT[t]
	if t.length() > 6:
		t = t.substr(0, 6)
	return t


## Names of all keys currently bound to an action (empty slots skipped).
func key_names(action: String) -> Array:
	var out: Array = []
	for k in key_binds[action]:
		if int(k) != 0:
			out.append(key_text(int(k)))
	return out


# ------------------------------------------------------------------ save / load
func save_game() -> void:
	var data := {
		"unlocked": unlocked,
		"best": best_scores,
		"music": music_volume,
		"sfx": sfx_volume,
		"fullscreen": fullscreen,
		"keys": key_binds,
		"pad": pad_binds,
		"wallet": wallet,
		"owned": owned.keys(),
		"loadout": loadout,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		_wallet_dirty = false


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	unlocked = int(parsed.get("unlocked", 1))
	best_scores = parsed.get("best", {})
	music_volume = float(parsed.get("music", 0.7))
	sfx_volume = float(parsed.get("sfx", 0.9))
	fullscreen = bool(parsed.get("fullscreen", false))
	_load_keys(parsed.get("keys", {}))
	_load_pad(parsed.get("pad", {}))
	wallet = maxi(0, int(parsed.get("wallet", 0)))
	_load_cosmetics(parsed.get("owned", []), parsed.get("loadout", {}))


func _load_pad(saved) -> void:
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for a in DEFAULT_PAD:
		if not saved.has(a) or typeof(saved[a]) != TYPE_ARRAY:
			continue
		var arr: Array = []
		for sl in KEY_SLOTS:
			arr.append(int(saved[a][sl]) if sl < (saved[a] as Array).size() else PAD_EMPTY)
		var has_one := false
		for c in arr:
			if int(c) != PAD_EMPTY:
				has_one = true
		if has_one:
			pad_binds[a] = arr


func _load_keys(saved) -> void:
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for a in DEFAULT_KEYS:
		if not saved.has(a) or typeof(saved[a]) != TYPE_ARRAY:
			continue
		var arr: Array = []
		for sl in KEY_SLOTS:
			arr.append(int(saved[a][sl]) if sl < (saved[a] as Array).size() else 0)
		var has_key := false
		for k in arr:
			if int(k) != 0:
				has_key = true
		if has_key:
			key_binds[a] = arr


func apply_settings() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	Audio.update_volumes()


# ------------------------------------------------------------------ run management
func level_count() -> int:
	return LevelsData.DATA.size()


func new_run(idx: int) -> void:
	current_level = idx
	lives = 3
	score = 0
	coins = 0
	run_earned = 0
	player_state = 0
	checkpoints.clear()


func has_next_level() -> bool:
	return current_level + 1 < level_count()


func go_next_level() -> void:
	current_level += 1
	checkpoints.clear()


func complete_level(final_score: int) -> void:
	earn_coins(CLEAR_BONUS)
	var key := str(current_level)
	if final_score > int(best_scores.get(key, 0)):
		best_scores[key] = final_score
	if current_level + 2 > unlocked:
		unlocked = min(current_level + 2, level_count())
	save_game()


func best_for(idx: int) -> int:
	return int(best_scores.get(str(idx), 0))


# ------------------------------------------------------------------ shop wallet / items
func _reset_cosmetics() -> void:
	owned = {}
	for id in Cosmetics.free_ids():
		owned[id] = true
	loadout = Cosmetics.default_loadout()


func _load_cosmetics(saved_owned, saved_loadout) -> void:
	_reset_cosmetics()
	if typeof(saved_owned) == TYPE_ARRAY:
		for id in saved_owned:
			if not Cosmetics.by_id(str(id)).is_empty():
				owned[str(id)] = true
	if typeof(saved_loadout) == TYPE_DICTIONARY:
		for slot in Cosmetics.SLOTS:
			var id := str(saved_loadout.get(slot, ""))
			var it := Cosmetics.by_id(id)
			if not it.is_empty() and it["slot"] == slot and owned.has(id):
				loadout[slot] = id


## Adds coins to the shop wallet. It is written to disk by flush_wallet() (when a level ends,
## on death, on leaving the level, or when the window closes) so nothing is ever lost.
func earn_coins(n: int) -> void:
	wallet += n
	run_earned += n
	_wallet_dirty = true


func flush_wallet() -> void:
	if _wallet_dirty:
		save_game()


func owns(id: String) -> bool:
	return owned.has(id)


func equipped(slot: String) -> String:
	return str(loadout.get(slot, ""))


## Buys an item. Returns "" on success or a short error text.
func buy_item(id: String) -> String:
	var it := Cosmetics.by_id(id)
	if it.is_empty():
		return "UNKNOWN ITEM"
	if owned.has(id):
		return "ALREADY OWNED"
	var price: int = it["price"]
	if wallet < price:
		return "NEED %d MORE COINS" % (price - wallet)
	wallet -= price
	owned[id] = true
	save_game()
	return ""


## Wears an owned item (id "" takes the slot's item off; skin / suit fall back to the classic one).
func equip_item(slot: String, id: String) -> void:
	if id != "" and not owned.has(id):
		return
	if id == "":
		if slot == "skin":
			id = "skin_classic"
		elif slot == "suit":
			id = "suit_classic"
	loadout[slot] = id
	save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		flush_wallet()


# ------------------------------------------------------------------ helpers
func tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


func make_frames(texture: Texture2D, fw: int, fh: int, anims: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for anim_name in anims:
		var a: Dictionary = anims[anim_name]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, a["fps"])
		sf.set_animation_loop(anim_name, a["loop"])
		for i in a["frames"]:
			var at := AtlasTexture.new()
			at.atlas = texture
			at.region = Rect2(i * fw, 0, fw, fh)
			sf.add_frame(anim_name, at)
	return sf


func make_sky(top: Color, bottom: Color) -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, top)
	grad.set_color(1, bottom)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(400, 224)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func chapter_of(idx: int) -> int:
	return clampi(idx / 10, 0, CHAPTERS.size() - 1)


## 1-based number of the level inside its chapter (1..10).
func level_in_chapter(idx: int) -> int:
	return idx % 10 + 1


func level_label(idx: int) -> String:
	return "%d-%d" % [idx / 5 + 1, idx % 5 + 1]
