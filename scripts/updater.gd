extends Control
## Mandatory auto-updater. This is the MAIN SCENE of the game (see project.godot).
##
## On start it asks the GitHub Releases API for the latest release of the repository.
## If the release is newer than "application/config/version" in project.godot, the player
## must update first: the new build is downloaded, then a small helper script waits for the
## game to close, copies the new files over the old ones and starts the game again.
## Windows and Linux replace the executable, macOS replaces the whole .app bundle.
## When the game is up to date (or offline, see ALLOW_OFFLINE) it goes on to the main menu.

# ---------------------------------------------------------------- SETTINGS
## Your GitHub account and repository name (the part after github.com/).
## Example: github.com/badutzy/super-pixel-bros -> OWNER "badutzy", REPO "super-pixel-bros"
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
const UPDATE_DIR := "user://update"
const BAR_W := 276.0

# ---------------------------------------------------------------- STATE
enum Step { CHECKING, REQUIRED, DOWNLOADING, INSTALLING, ERROR }

const ScrollerScript = preload("res://scripts/scroller.gd")

var _step: Step = Step.CHECKING
var _local_version := ""
var _remote_tag := ""
var _release_url := ""
var _asset_name := ""
var _asset_url := ""
var _asset_size := 0
var _asset_digest := ""
var _pkg_path := ""
var _http: HTTPRequest
var _dl: HTTPRequest

var _title: Label
var _info: Label
var _bar_bg: ColorRect
var _bar_fill: ColorRect
var _buttons: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_local_version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	_cleanup_stale()
	if _should_skip():
		get_tree().change_scene_to_file.call_deferred(MENU_SCENE)
		return
	_build_ui()
	_check()


func _should_skip() -> bool:
	if OS.get_name() not in ["Windows", "Linux", "macOS"]:
		return true
	if OS.has_feature("editor") and not CHECK_IN_EDITOR:
		return true
	if GITHUB_OWNER == "USERNAME" or GITHUB_REPO == "REPOSITORY":
		push_warning("Updater: set GITHUB_OWNER and GITHUB_REPO in scripts/updater.gd")
		return true
	return false


func _process(_delta: float) -> void:
	if _step == Step.DOWNLOADING and is_instance_valid(_dl):
		var got := _dl.get_downloaded_bytes()
		var total := _dl.get_body_size()
		if total <= 0:
			total = _asset_size
		var frac := 0.0
		if total > 0:
			frac = clampf(float(got) / float(total), 0.0, 1.0)
		_bar_fill.size.x = floorf((BAR_W - 4.0) * frac)
		var txt := "%d%%\n%.1f MB" % [int(frac * 100.0), got / 1048576.0]
		if total > 0:
			txt = "%d%%\n%.1f / %.1f MB" % [int(frac * 100.0), got / 1048576.0, total / 1048576.0]
		_info.text = "PLEASE DO NOT CLOSE\nTHE GAME.\n\n" + txt


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

	_bar_bg = ColorRect.new()
	_bar_bg.color = UI.INK
	_bar_bg.custom_minimum_size = Vector2(BAR_W, 10)
	_bar_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar_bg.visible = false
	box.add_child(_bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = UI.MINT
	_bar_fill.position = Vector2(2, 2)
	_bar_fill.size = Vector2(0, 6)
	_bar_bg.add_child(_bar_fill)

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
		var b := UI.button(e[0], e[1], 160)
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
func _new_http() -> HTTPRequest:
	var h := HTTPRequest.new()
	add_child(h)
	return h


func _check() -> void:
	_step = Step.CHECKING
	_title.text = "CHECKING FOR UPDATE"
	_info.text = "PLEASE WAIT..."
	_bar_bg.visible = false
	_set_buttons([])
	_http = _new_http()
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
	_pick_asset(rel.get("assets", []))
	_show_required()


func _on_unreachable(reason: String) -> void:
	if ALLOW_OFFLINE:
		_enter_menu()
		return
	_show_error("CANNOT CHECK UPDATE", reason + "\n\nAN INTERNET CONNECTION IS REQUIRED.", _check, false)


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


## Picks the download that matches this operating system by file name:
## Windows needs "windows" in the name (.zip or .exe), Linux needs "linux" (.zip or .x86_64),
## macOS needs "macos" (or "mac" / "osx") in the name (.zip that contains the .app).
func _pick_asset(assets: Variant) -> void:
	_asset_name = ""
	_asset_url = ""
	_asset_size = 0
	_asset_digest = ""
	if typeof(assets) != TYPE_ARRAY:
		return
	var keys: Array = []
	var exts: Array = []
	match OS.get_name():
		"Windows":
			keys = ["windows", "win64", "win32"]
			exts = [".zip", ".exe"]
		"Linux":
			keys = ["linux"]
			exts = [".zip", ".x86_64"]
		"macOS":
			keys = ["macos", "osx", "mac"]
			exts = [".zip"]
		_:
			return
	for a in assets:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = a
		var n := str(d.get("name", "")).to_lower()
		var ext_ok := false
		for e in exts:
			if n.ends_with(e):
				ext_ok = true
		var key_ok := false
		for k in keys:
			if n.contains(k):
				key_ok = true
		if ext_ok and key_ok:
			_asset_name = str(d.get("name", ""))
			_asset_url = str(d.get("browser_download_url", ""))
			_asset_size = int(d.get("size", 0))
			_asset_digest = str(d.get("digest", ""))
			return


# ---------------------------------------------------------------- REQUIRED SCREEN
func _show_required() -> void:
	_step = Step.REQUIRED
	_bar_bg.visible = false
	_title.text = "UPDATE REQUIRED"
	_info.text = "NEW VERSION: V%s\nYOUR VERSION: V%s\n\nYOU MUST UPDATE\nBEFORE YOU CAN PLAY." % [
		_remote_tag.trim_prefix("v").trim_prefix("V"), _local_version]
	if OS.get_name() == "macOS" and _mac_bundle() == "":
		_info.text += "\n\nMOVE THE GAME TO YOUR\nAPPLICATIONS FOLDER AND\nOPEN IT FROM THERE TO\nUPDATE AUTOMATICALLY."
		_set_buttons([["OPEN DOWNLOAD PAGE", _open_release_page], ["QUIT", _quit]])
	elif _asset_url != "":
		_set_buttons([["UPDATE NOW", _start_download], ["QUIT", _quit]])
	else:
		_info.text += "\n\nAUTO UPDATE IS NOT AVAILABLE\nFOR THIS SYSTEM."
		_set_buttons([["OPEN DOWNLOAD PAGE", _open_release_page], ["QUIT", _quit]])


func _show_error(title: String, msg: String, retry: Callable, with_page: bool = true) -> void:
	_step = Step.ERROR
	_bar_bg.visible = false
	_title.text = title
	_info.text = msg
	var entries: Array = [["TRY AGAIN", retry]]
	if with_page and _release_url != "":
		entries.append(["OPEN DOWNLOAD PAGE", _open_release_page])
	entries.append(["QUIT", _quit])
	_set_buttons(entries)


# ---------------------------------------------------------------- DOWNLOAD
func _start_download() -> void:
	_step = Step.DOWNLOADING
	_set_buttons([])
	_title.text = "DOWNLOADING"
	_info.text = "PLEASE DO NOT CLOSE\nTHE GAME."
	_bar_fill.size.x = 0
	_bar_bg.visible = true

	var dir := ProjectSettings.globalize_path(UPDATE_DIR)
	_rm_rf(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	_pkg_path = dir.path_join("package." + _asset_name.get_extension().to_lower())

	_dl = _new_http()
	_dl.download_file = _pkg_path
	_dl.use_threads = true
	_dl.request_completed.connect(_on_download_done)
	var err := _dl.request(_asset_url, ["User-Agent: " + USER_AGENT])
	if err != OK:
		_dl.queue_free()
		_dl = null
		_show_error("DOWNLOAD FAILED", "COULD NOT START THE DOWNLOAD.", _start_download)


func _on_download_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_dl.queue_free()
	_dl = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_show_error("DOWNLOAD FAILED", "CHECK YOUR INTERNET\nCONNECTION AND TRY AGAIN.", _start_download)
		return
	if not _verify_package():
		_show_error("DOWNLOAD CORRUPT", "THE DOWNLOADED FILE IS\nINCOMPLETE. TRY AGAIN.", _start_download)
		return
	_install()


func _verify_package() -> bool:
	var f := FileAccess.open(_pkg_path, FileAccess.READ)
	if f == null:
		return false
	var length := f.get_length()
	f.close()
	if _asset_size > 0 and length != _asset_size:
		return false
	if _asset_digest.begins_with("sha256:"):
		var want := _asset_digest.trim_prefix("sha256:").to_lower()
		if FileAccess.get_sha256(_pkg_path).to_lower() != want:
			return false
	return true


# ---------------------------------------------------------------- INSTALL
func _install() -> void:
	_step = Step.INSTALLING
	_title.text = "INSTALLING"
	_info.text = "THE GAME WILL RESTART\nAUTOMATICALLY..."
	_bar_fill.size.x = BAR_W - 4.0
	# let the new text render before the (blocking) unzip starts
	await get_tree().process_frame
	await get_tree().process_frame

	var dir := ProjectSettings.globalize_path(UPDATE_DIR)
	var stage := dir.path_join("stage")
	DirAccess.make_dir_recursive_absolute(stage)
	var cur_exe := OS.get_executable_path()
	var cur_name := cur_exe.get_file()

	if OS.get_name() == "macOS":
		await _install_mac(dir, stage)
		return

	if _pkg_path.ends_with(".zip"):
		if not _extract_zip(_pkg_path, stage):
			_show_error("INSTALL FAILED", "COULD NOT UNPACK THE\nDOWNLOADED FILE.", _start_download)
			return
	else:
		# a bare executable: keep the name the player already has
		DirAccess.copy_absolute(_pkg_path, stage.path_join(cur_name))

	var found := _find_game_file(stage, cur_name)
	if found == "":
		_show_error("INSTALL FAILED", "THE DOWNLOAD DOES NOT\nCONTAIN THE GAME FILE.", _start_download)
		return
	# always keep the current file name so shortcuts keep working
	if found.get_file() != cur_name:
		var renamed := found.get_base_dir().path_join(cur_name)
		DirAccess.rename_absolute(found, renamed)
		found = renamed

	var src_dir := found.get_base_dir()
	var dest_dir := cur_exe.get_base_dir()
	if not _launch_updater(dir, src_dir, dest_dir, cur_name):
		_show_error("INSTALL FAILED", "COULD NOT START THE\nINSTALLER.", _start_download)
		return
	await get_tree().create_timer(0.7).timeout
	get_tree().quit()


## macOS: unzip with the system "ditto" (keeps permissions and the app signature), then
## replace the whole .app bundle the player is running from.
func _install_mac(dir: String, stage: String) -> void:
	var bundle := _mac_bundle()
	if bundle == "":
		_show_error("MOVE THE GAME FIRST", "MOVE THE GAME TO YOUR\nAPPLICATIONS FOLDER, OPEN IT\nFROM THERE AND UPDATE.", _start_download)
		return
	var out: Array = []
	var code := OS.execute("/usr/bin/ditto", PackedStringArray(["-x", "-k", _pkg_path, stage]), out)
	if code != 0:
		_show_error("INSTALL FAILED", "COULD NOT UNPACK THE\nDOWNLOADED FILE.", _start_download)
		return
	var app := _find_app(stage)
	if app == "":
		_show_error("INSTALL FAILED", "THE DOWNLOAD DOES NOT\nCONTAIN THE GAME APP.", _start_download)
		return
	if not _launch_updater(dir, app, bundle, ""):
		_show_error("INSTALL FAILED", "COULD NOT START THE\nINSTALLER.", _start_download)
		return
	await get_tree().create_timer(0.7).timeout
	get_tree().quit()


## Path of the running .app bundle, or "" when the game is not inside a normal .app
## (or macOS runs it from a read-only "AppTranslocation" copy because it was never moved).
func _mac_bundle() -> String:
	var p := OS.get_executable_path()
	var i := p.find(".app/")
	if i == -1:
		return ""
	var b := p.substr(0, i + 4)
	if b.contains("/AppTranslocation/"):
		return ""
	return b


func _find_app(dir: String) -> String:
	for d in DirAccess.get_directories_at(dir):
		if d == "__MACOSX":
			continue
		if d.ends_with(".app"):
			return dir.path_join(d)
		var r := _find_app(dir.path_join(d))
		if r != "":
			return r
	return ""


func _extract_zip(zip_path: String, out_dir: String) -> bool:
	var zr := ZIPReader.new()
	if zr.open(zip_path) != OK:
		return false
	for entry in zr.get_files():
		var clean := String(entry).replace("\\", "/")
		if clean.begins_with("/") or clean.contains(":") or ".." in clean.split("/"):
			zr.close()
			return false
		var target := out_dir.path_join(clean)
		if clean.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(target)
			continue
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var f := FileAccess.open(target, FileAccess.WRITE)
		if f == null:
			zr.close()
			return false
		f.store_buffer(zr.read_file(entry))
		f.close()
	zr.close()
	return true


## Finds the game executable inside the unpacked update (prefers the same file name).
func _find_game_file(dir: String, cur_name: String) -> String:
	var exact := _find_file(dir, func(n: String) -> bool: return n == cur_name)
	if exact != "":
		return exact
	if OS.get_name() == "Windows":
		return _find_file(dir, func(n: String) -> bool:
			return n.get_extension().to_lower() == "exe" and not n.to_lower().contains("console"))
	return _find_file(dir, func(n: String) -> bool: return n.get_extension().to_lower() == "x86_64")


func _find_file(dir: String, want: Callable) -> String:
	for f in DirAccess.get_files_at(dir):
		if want.call(f):
			return dir.path_join(f)
	for d in DirAccess.get_directories_at(dir):
		var r := _find_file(dir.path_join(d), want)
		if r != "":
			return r
	return ""


# ---------------------------------------------------------------- HELPER SCRIPT
## Writes a small script that waits for this game to exit, copies the new files over the
## old ones and starts the game again. It cannot run inside the game because a running
## .exe cannot overwrite itself.
func _launch_updater(dir: String, src: String, dest: String, exe: String) -> bool:
	var pid := OS.get_process_id()
	match OS.get_name():
		"Windows":
			var ps := dir.path_join("apply_update.ps1")
			var lines := PackedStringArray([
				"$ErrorActionPreference = 'Stop'",
				"$gamePid = %d" % pid,
				"$src = %s" % _psq(src),
				"$dest = %s" % _psq(dest),
				"$exe = %s" % _psq(exe),
				"$url = %s" % _psq(_release_url),
				"try { Wait-Process -Id $gamePid -Timeout 40 } catch {}",
				"$ok = $false",
				"for ($i = 0; $i -lt 60 -and -not $ok; $i++) {",
				"  try {",
				"    Copy-Item -Path (Join-Path $src '*') -Destination $dest -Recurse -Force",
				"    $ok = $true",
				"  } catch { Start-Sleep -Seconds 1 }",
				"}",
				"if ($ok) {",
				"  Start-Process -FilePath (Join-Path $dest $exe) -WorkingDirectory $dest",
				"} elseif ($url -ne '') {",
				"  Start-Process $url",
				"}",
			])
			if not _write_text(ps, "\r\n".join(lines) + "\r\n", true):
				return false
			var args := PackedStringArray(["-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden",
				"-ExecutionPolicy", "Bypass", "-File", ps])
			return OS.create_process("powershell.exe", args) > 0
		"Linux":
			var sh := dir.path_join("apply_update.sh")
			var lines := PackedStringArray([
				"#!/bin/sh",
				"PID=%d" % pid,
				"SRC=%s" % _shq(src),
				"DEST=%s" % _shq(dest),
				"EXE=%s" % _shq(exe),
				"URL=%s" % _shq(_release_url),
				"i=0",
				"while kill -0 \"$PID\" 2>/dev/null && [ $i -lt 80 ]; do sleep 0.5; i=$((i+1)); done",
				"ok=0; n=0",
				"while [ $n -lt 40 ]; do",
				"  if cp -rf \"$SRC\"/. \"$DEST\"/ 2>/dev/null; then ok=1; break; fi",
				"  sleep 1; n=$((n+1))",
				"done",
				"if [ \"$ok\" = 1 ]; then",
				"  chmod +x \"$DEST/$EXE\"",
				"  cd \"$DEST\" && nohup \"$DEST/$EXE\" >/dev/null 2>&1 &",
				"elif [ -n \"$URL\" ]; then",
				"  xdg-open \"$URL\" >/dev/null 2>&1 &",
				"fi",
			])
			if not _write_text(sh, "\n".join(lines) + "\n", false):
				return false
			return OS.create_process("/bin/sh", PackedStringArray([sh])) > 0
		"macOS":
			var msh := dir.path_join("apply_update.sh")
			var mlines := PackedStringArray([
				"#!/bin/sh",
				"PID=%d" % pid,
				"SRC=%s" % _shq(src),
				"DEST=%s" % _shq(dest),
				"URL=%s" % _shq(_release_url),
				"BAK=\"$DEST.old\"",
				"i=0",
				"while kill -0 \"$PID\" 2>/dev/null && [ $i -lt 80 ]; do sleep 0.5; i=$((i+1)); done",
				"ok=0",
				"rm -rf \"$BAK\"",
				"if mv \"$DEST\" \"$BAK\" 2>/dev/null; then",
				"  if /usr/bin/ditto \"$SRC\" \"$DEST\" 2>/dev/null; then",
				"    ok=1",
				"  else",
				"    rm -rf \"$DEST\"; mv \"$BAK\" \"$DEST\"",
				"  fi",
				"fi",
				"if [ \"$ok\" = 1 ]; then",
				"  chmod -R u+x \"$DEST/Contents/MacOS\"",
				"  /usr/bin/xattr -dr com.apple.quarantine \"$DEST\" 2>/dev/null",
				"  rm -rf \"$BAK\"",
				"  /usr/bin/open \"$DEST\"",
				"elif [ -n \"$URL\" ]; then",
				"  /usr/bin/open \"$URL\"",
				"fi",
			])
			if not _write_text(msh, "\n".join(mlines) + "\n", false):
				return false
			return OS.create_process("/bin/sh", PackedStringArray([msh])) > 0
	return false


func _psq(s: String) -> String:
	return "'" + s.replace("'", "''") + "'"


func _shq(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"


func _write_text(path: String, text: String, bom: bool) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	if bom:
		f.store_8(0xEF)
		f.store_8(0xBB)
		f.store_8(0xBF)
	f.store_string(text)
	f.close()
	return true


# ---------------------------------------------------------------- CLEANUP
## Removes the leftovers of a previous update (downloads and helper scripts).
func _cleanup_stale() -> void:
	var dir := ProjectSettings.globalize_path(UPDATE_DIR)
	if DirAccess.dir_exists_absolute(dir):
		_rm_rf(dir)


func _rm_rf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for d in DirAccess.get_directories_at(path):
		_rm_rf(path.path_join(d))
	DirAccess.remove_absolute(path)
