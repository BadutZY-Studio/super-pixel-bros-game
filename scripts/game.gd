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

# --- touch settings read from the save file (TouchUI picks them up in its own _ready)
var touch_saved := {}

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
	load_game()
	apply_settings()


# ------------------------------------------------------------------ input
## Fixed bindings. The game is touch-first now, so there is no rebinding screen any more, but a
## keyboard or a gamepad that is plugged into the phone (USB / OTG / Bluetooth) keeps working:
##   keyboard: arrows / WASD move, Space Z K W Up jump, Shift X J run + fire, Esc P pause
##   gamepad : stick / D-pad move, A Y jump, X B RT run + fire, Start pause
## "dash" (run only) and "fire" (fireball only) are used by the separate on-screen buttons.
func _setup_inputs() -> void:
	for a in ["left", "right", "jump", "run", "pause", "down", "dash", "fire"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.3)
	_key_action("left", [KEY_LEFT, KEY_A])
	_key_action("right", [KEY_RIGHT, KEY_D])
	_key_action("down", [KEY_DOWN, KEY_S])
	_key_action("jump", [KEY_SPACE, KEY_Z, KEY_UP, KEY_W, KEY_K])
	_key_action("run", [KEY_SHIFT, KEY_X, KEY_J])
	_key_action("pause", [KEY_ESCAPE, KEY_P])
	_setup_controller()


## Gamepad layout. Stick / D-pad = move. Menus: stick / D-pad = move focus, A or X = select,
## B = back (added explicitly if missing so a controller always works in the UI).
func _setup_controller() -> void:
	_pad_button("left", JOY_BUTTON_DPAD_LEFT)
	_pad_button("right", JOY_BUTTON_DPAD_RIGHT)
	_pad_button("down", JOY_BUTTON_DPAD_DOWN)
	_pad_axis("left", JOY_AXIS_LEFT_X, -1.0)
	_pad_axis("right", JOY_AXIS_LEFT_X, 1.0)
	_pad_axis("down", JOY_AXIS_LEFT_Y, 1.0)
	_pad_button("jump", JOY_BUTTON_A)
	_pad_button("jump", JOY_BUTTON_Y)
	_pad_button("run", JOY_BUTTON_X)
	_pad_button("run", JOY_BUTTON_B)
	_pad_axis("run", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_pad_button("pause", JOY_BUTTON_START)
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


# ------------------------------------------------------------------ save / load
func save_game() -> void:
	var data := {
		"unlocked": unlocked,
		"best": best_scores,
		"music": music_volume,
		"sfx": sfx_volume,
		"fullscreen": fullscreen,
		"touch": TouchUI.to_dict() if is_instance_valid(TouchUI) else touch_saved,
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
	var ts = parsed.get("touch", {})
	if typeof(ts) == TYPE_DICTIONARY:
		touch_saved = ts
	wallet = maxi(0, int(parsed.get("wallet", 0)))
	_load_cosmetics(parsed.get("owned", []), parsed.get("loadout", {}))


func apply_settings() -> void:
	if OS.has_feature("mobile"):
		Audio.update_volumes()
		return
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


## Android BACK button: closes whatever is open (editor / panels) or pauses the level.
func _send_action(action: String) -> void:
	for p in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = p
		ev.strength = 1.0 if p else 0.0
		Input.parse_input_event(ev)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var scn := get_tree().current_scene
		if is_instance_valid(TouchUI) and TouchUI.editing:
			_send_action("ui_cancel")
		elif scn != null and scn.has_method("touch_active"):
			_send_action("pause")
		else:
			_send_action("ui_cancel")
		return
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
