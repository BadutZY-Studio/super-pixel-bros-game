extends Control
## Mandatory update check for the Android build. This is the MAIN SCENE of the game.
##
## On start it asks the GitHub Releases API for the latest release of the repository.
## If that release is newer than "application/config/version" in project.godot, the player
## must update first: the game offers a single button that downloads the new APK, and the
## menu stays locked until the new version is installed.
##
## Android never lets a normal app install another APK silently, so the last step (tapping
## INSTALL in the system dialog) is always done by the player. Installing over the old game
## keeps all save data, as long as the new APK uses the same package name and signing key.

# ---------------------------------------------------------------- SETTINGS
## Same repository as the PC build (the part after github.com/).
## The repository must be PUBLIC, otherwise the Releases API cannot be read without a token.
const GITHUB_OWNER := "BadutZY-Studio"
const GITHUB_REPO := "super-pixel-bros-game"

## true  = if the check fails (no internet, GitHub down) the player may still play.
## false = the player cannot play until the check succeeds.
const ALLOW_OFFLINE := true

## Skip the check when running from the Godot editor (F5), so development is never blocked.
## Set to true to test the update screen from the editor.
const CHECK_IN_EDITOR := false

const REQUEST_TIMEOUT := 12.0
const USER_AGENT := "SuperPixelBros-Updater"
const MENU_SCENE := "res://scenes/menu.tscn"
const BAR_W := 276.0

# ---------------------------------------------------------------- STATE
enum Step { CHECKING, REQUIRED, DOWNLOADING, ERROR }

const ScrollerScript = preload("res://scripts/scroller.gd")

var _step: Step = Step.CHECKING
var _local_version := ""
var _remote_tag := ""
var _release_url := ""
var _apk_url := ""
var _http: HTTPRequest

var _title: Label
var _info: Label
var _buttons: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_local_version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	if _should_skip():
		get_tree().change_scene_to_file.call_deferred(MENU_SCENE)
		return
	_build_ui()
	_check()


func _should_skip() -> bool:
	if OS.has_feature("editor") and not CHECK_IN_EDITOR:
		return true
	if OS.get_name() != "Android" and not CHECK_IN_EDITOR:
		return true
	if GITHUB_OWNER == "USERNAME" or GITHUB_REPO == "REPOSITORY":
		push_warning("Updater: set GITHUB_OWNER and GITHUB_REPO in scripts/updater.gd")
		return true
	return false


# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	Audio.play_music("menu")
	var th: Dictionary = Game.LevelsData.THEMES["grass"]
	add_child(Game.make_sky(th["sky_top"], th["sky_bot"]))
	_scroller("res://assets/bg/bg_grass_far.png", 0.5, 200.0, 6.0)
	_scroller("res://assets/bg/bg_grass_near.png", 0.5, 204.0, 14.0)
	_build_ground()
	add_child(UI.ribbon_centered("UPDATE", 14, 16, UI.RED))

	var center := CenterContainer.new()
	center.position = Vector2(0, 50)
	center.size = Vector2(400, 166)
	add_child(center)
	var panel := UI.panel(Vector2(300, 0))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)

	_title = UI.label("", 8, UI.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_info = UI.label("", 8, Color.WHITE)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(BAR_W, 0)
	box.add_child(_info)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 5)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_buttons)

	add_child(UI.vignette(0.45))


func _scroller(path: String, f: float, bottom: float, speed: float) -> void:
	var s = ScrollerScript.new()
	add_child(s)
	s.setup(Game.tex(path), f, bottom, speed)


func _build_ground() -> void:
	var tiles := Game.tex("res://assets/tiles/tiles_grass.png")
	var top := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = tiles
	at.region = Rect2(0, 0, 16, 16)
	top.texture = at
	top.stretch_mode = TextureRect.STRETCH_TILE
	top.position = Vector2(0, 192)
	top.size = Vector2(400, 16)
	add_child(top)
	var fill := TextureRect.new()
	var at2 := AtlasTexture.new()
	at2.atlas = tiles
	at2.region = Rect2(16, 0, 16, 16)
	fill.texture = at2
	fill.stretch_mode = TextureRect.STRETCH_TILE
	fill.position = Vector2(0, 208)
	fill.size = Vector2(400, 16)
	add_child(fill)


## Replaces the button list. Each entry is [text, Callable].
func _set_buttons(entries: Array) -> void:
	for c in _buttons.get_children():
		c.queue_free()
	var made: Array = []
	for e in entries:
		var b := UI.button(e[0], e[1], 170)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_buttons.add_child(b)
		made.append(b)
	if made.is_empty():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var rows: Array = []
	for b in made:
		rows.append([b])
	UI.wire_focus_grid(rows)
	(made[0] as Button).grab_focus()


func _quit() -> void:
	get_tree().quit()


func _open_release_page() -> void:
	if _release_url != "":
		OS.shell_open(_release_url)


# ---------------------------------------------------------------- CHECK
func _check() -> void:
	_step = Step.CHECKING
	_title.text = "CHECKING FOR UPDATE"
	_info.text = "PLEASE WAIT..."
	_set_buttons([])
	_http = HTTPRequest.new()
	add_child(_http)
	_http.timeout = REQUEST_TIMEOUT
	_http.request_completed.connect(_on_check_done)
	var url := "https://api.github.com/repos/%s/%s/releases/latest" % [GITHUB_OWNER, GITHUB_REPO]
	var err := _http.request(url, ["User-Agent: " + USER_AGENT, "Accept: application/vnd.github+json"])
	if err != OK:
		_http.queue_free()
		_on_unreachable("REQUEST FAILED")


func _on_check_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		_on_unreachable("NO CONNECTION")
		return
	if code == 404:
		# The repository has no published release yet: nothing to update to.
		_enter_menu()
		return
	if code != 200:
		_on_unreachable("SERVER ERROR " + str(code))
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_on_unreachable("BAD RESPONSE")
		return
	var rel: Dictionary = parsed
	_remote_tag = str(rel.get("tag_name", ""))
	_release_url = str(rel.get("html_url", ""))
	if not _is_newer(_remote_tag, _local_version):
		_enter_menu()
		return
	_apk_url = _find_apk(rel.get("assets", []))
	if _apk_url == "":
		# The newest release has no Android APK (for example a PC-only release),
		# so there is nothing to update to on this device: just play.
		_enter_menu()
		return
	_show_required()


func _on_unreachable(reason: String) -> void:
	if ALLOW_OFFLINE:
		_enter_menu()
		return
	_step = Step.ERROR
	_title.text = "CANNOT CHECK UPDATE"
	_info.text = reason + "\n\nAN INTERNET CONNECTION IS REQUIRED."
	_set_buttons([["TRY AGAIN", _check], ["QUIT", _quit]])


func _enter_menu() -> void:
	UI.go(MENU_SCENE)


# ---------------------------------------------------------------- VERSIONS
func _parse_version(v: String) -> Array:
	var s := v.strip_edges().to_lower().trim_prefix("v")
	var out: Array = []
	for part in s.replace("-", ".").replace("+", ".").split("."):
		if part.is_valid_int():
			out.append(int(part))
		else:
			break
	return out


func _is_newer(remote: String, local: String) -> bool:
	var r := _parse_version(remote)
	var l := _parse_version(local)
	if r.is_empty():
		return false
	var n := maxi(r.size(), l.size())
	for i in n:
		var a: int = r[i] if i < r.size() else 0
		var b: int = l[i] if i < l.size() else 0
		if a != b:
			return a > b
	return false


## Returns the download link of the Android APK in the release ("" if there is none).
## Any file that ends with .apk is accepted; one that has "android" in its name is preferred.
func _find_apk(assets: Variant) -> String:
	if typeof(assets) != TYPE_ARRAY:
		return ""
	var fallback := ""
	for a in assets:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = a
		var n := str(d.get("name", "")).to_lower()
		if not n.ends_with(".apk"):
			continue
		var link := str(d.get("browser_download_url", ""))
		if n.contains("android"):
			return link
		if fallback == "":
			fallback = link
	return fallback


# ---------------------------------------------------------------- SCREENS
func _show_required() -> void:
	_step = Step.REQUIRED
	_title.text = "UPDATE REQUIRED"
	_info.text = "NEW VERSION: V%s\nYOUR VERSION: V%s\n\nYOU MUST UPDATE\nBEFORE YOU CAN PLAY." % [
		_remote_tag.trim_prefix("v").trim_prefix("V"), _local_version]
	_set_buttons([["UPDATE NOW", _start_update], ["OPEN DOWNLOAD PAGE", _open_release_page], ["QUIT", _quit]])


## Opens the APK link: the phone downloads the file, then the player taps it to install.
func _start_update() -> void:
	_step = Step.DOWNLOADING
	_title.text = "DOWNLOAD STARTED"
	_info.text = "1. WAIT FOR THE DOWNLOAD\n2. OPEN THE APK FILE\n3. TAP INSTALL\n4. OPEN THE GAME AGAIN\n\nALLOW INSTALLING IF ASKED."
	OS.shell_open(_apk_url)
	_set_buttons([["DOWNLOAD AGAIN", _start_update], ["QUIT", _quit]])
