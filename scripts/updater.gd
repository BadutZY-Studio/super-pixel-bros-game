extends Control
## Mandatory update check for the Android build. This is the MAIN SCENE of the game.
##
## On start it reads the releases of the GitHub repository and finds the highest version that
## contains an APK. If that version is newer than "application/config/version" in project.godot,
## the player must update first and the menu stays locked:
##   1. UPDATE NOW downloads the APK inside the game (with a progress bar),
##   2. then INSTALL NOW opens the Android installer for the downloaded file.
## Android never installs an app silently, so the player always confirms in the system dialog.
## Installing over the old game keeps all save data, as long as the new APK uses the same
## package name and the same signing key.
##
## The in-game download and install use the Android APIs through JavaClassWrapper (Godot 4.4+).
## If anything in that path is not available, the game falls back to opening the APK link in the
## browser (the old behaviour), so the player can always update.
##
## REQUIRED export setting: Project > Export > Android > Options > Permissions > Custom
## Permissions must contain  android.permission.REQUEST_INSTALL_PACKAGES  (and Internet must be on).

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

## How long (seconds) the result of the check stays on screen before the menu opens, so you
## can always see WHY the game let the player in (up to date, no APK found, offline...).
## Set to 0 to go straight to the menu.
const RESULT_SECONDS := 1.5

const REQUEST_TIMEOUT := 12.0
## The download is reported as failed when no new bytes arrive for this long.
const STALL_SECONDS := 60.0
const USER_AGENT := "SuperPixelBros-Updater"
const MENU_SCENE := "res://scenes/menu.tscn"
const BAR_W := 276.0

# Android constants (see android.content.Intent and android.app.DownloadManager)
const FLAG_GRANT_READ_URI_PERMISSION := 1
const FLAG_ACTIVITY_NEW_TASK := 0x10000000
const DM_STATUS_SUCCESSFUL := 8
const DM_STATUS_FAILED := 16
const APK_MIME := "application/vnd.android.package-archive"

# ---------------------------------------------------------------- STATE
enum Step { CHECKING, REQUIRED, DOWNLOADING, READY, ERROR }

const ScrollerScript = preload("res://scripts/scroller.gd")

var _step: Step = Step.CHECKING
var _local_version := ""
var _remote_tag := ""
var _release_url := ""
var _apk_url := ""
var _asset_size := 0
var _asset_digest := ""
var _http: HTTPRequest

# in-game download (Android DownloadManager)
var _dm = null
var _dl_id := -1
var _dl_dir := ""
var _dl_path := ""
var _apk_uri = null
var _poll_t := 0.0
var _stall_t := 0.0
var _last_got := 0

var _title: Label
var _info: Label
var _bar_bg: ColorRect
var _bar_fill: ColorRect
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
	_bar_bg.visible = false
	_title.text = "CHECKING FOR UPDATE"
	_info.text = "PLEASE WAIT..."
	_set_buttons([])
	_http = HTTPRequest.new()
	add_child(_http)
	_http.timeout = REQUEST_TIMEOUT
	_http.request_completed.connect(_on_check_done)
	# The list of releases is read (not just "latest"), see _on_check_done for why.
	var url := "https://api.github.com/repos/%s/%s/releases?per_page=30" % [GITHUB_OWNER, GITHUB_REPO]
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
		_skip("NO RELEASE FOUND", "REPOSITORY: %s/%s\nCHECK THE NAME AND MAKE SURE\nIT IS PUBLIC." % [GITHUB_OWNER, GITHUB_REPO])
		return
	if code != 200:
		_on_unreachable("GITHUB ERROR " + str(code))
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_ARRAY:
		_on_unreachable("BAD RESPONSE")
		return

	# Look through ALL published releases and pick the highest version that has an APK.
	# GitHub's own "Latest" badge is not used on purpose: it can stay on an older release
	# (it follows the date of the commit, not the date the release was published), and a
	# release made only for PC must not hide an Android release.
	var best_tag := ""
	var best_page := ""
	var best_asset := {}
	for r in parsed:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var rel: Dictionary = r
		if rel.get("draft", false) or rel.get("prerelease", false):
			continue
		var tag := str(rel.get("tag_name", ""))
		if _parse_version(tag).is_empty():
			continue
		var asset := _find_apk(rel.get("assets", []))
		if asset.is_empty():
			continue
		if best_tag == "" or _is_newer(tag, best_tag):
			best_tag = tag
			best_page = str(rel.get("html_url", ""))
			best_asset = asset

	if best_tag == "":
		_skip("NO ANDROID BUILD FOUND", "NO RELEASE HAS AN APK FILE.\nYOUR VERSION: V%s" % _local_version)
		return
	_remote_tag = best_tag
	_release_url = best_page
	_apk_url = str(best_asset["url"])
	_asset_size = int(best_asset["size"])
	_asset_digest = str(best_asset["digest"])
	if not _is_newer(_remote_tag, _local_version):
		_cleanup_downloads()
		_skip("UP TO DATE", "YOUR VERSION: V%s\nNEWEST ANDROID: V%s" % [_local_version, _clean_tag(_remote_tag)])
		return
	_show_required()


func _on_unreachable(reason: String) -> void:
	if ALLOW_OFFLINE:
		_skip("COULD NOT CHECK", reason + "\nPLAYING WITHOUT UPDATE CHECK.")
		return
	_step = Step.ERROR
	_title.text = "CANNOT CHECK UPDATE"
	_info.text = reason + "\n\nAN INTERNET CONNECTION IS REQUIRED."
	_set_buttons([["TRY AGAIN", _check], ["QUIT", _quit]])


## Shows the result of the check for RESULT_SECONDS, then opens the menu.
func _skip(title: String, msg: String) -> void:
	_step = Step.CHECKING
	_title.text = title
	_info.text = msg
	_set_buttons([])
	if RESULT_SECONDS > 0.0:
		await get_tree().create_timer(RESULT_SECONDS).timeout
	_enter_menu()


func _clean_tag(tag: String) -> String:
	return tag.trim_prefix("v").trim_prefix("V")


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


## Returns {url, size, digest} of the Android APK in a release, or {} if there is none.
## Any file that ends with .apk is accepted; one that has "android" in its name is preferred.
func _find_apk(assets: Variant) -> Dictionary:
	if typeof(assets) != TYPE_ARRAY:
		return {}
	var fallback := {}
	for a in assets:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = a
		var n := str(d.get("name", "")).to_lower()
		if not n.ends_with(".apk"):
			continue
		var found := {
			"url": str(d.get("browser_download_url", "")),
			"size": int(d.get("size", 0)),
			"digest": str(d.get("digest", "")),
		}
		if n.contains("android"):
			return found
		if fallback.is_empty():
			fallback = found
	return fallback


# ---------------------------------------------------------------- UPDATE SCREEN
func _show_required() -> void:
	_step = Step.REQUIRED
	_bar_bg.visible = false
	_title.text = "UPDATE REQUIRED"
	_info.text = "NEW VERSION: V%s\nYOUR VERSION: V%s\n\nYOU MUST UPDATE\nBEFORE YOU CAN PLAY." % [
		_clean_tag(_remote_tag), _local_version]
	_set_buttons([["UPDATE NOW", _start_update], ["OPEN DOWNLOAD PAGE", _open_release_page], ["QUIT", _quit]])


func _start_update() -> void:
	if _android_ready() and _begin_download():
		return
	_browser_download()


## Fallback: opens the APK link in the browser; the phone downloads it and the player taps it.
func _browser_download() -> void:
	_step = Step.READY
	_dl_id = -1
	_bar_bg.visible = false
	_title.text = "DOWNLOAD STARTED"
	_info.text = "1. WAIT FOR THE DOWNLOAD\n2. OPEN THE APK FILE\n3. TAP INSTALL\n4. OPEN THE GAME AGAIN\n\nALLOW INSTALLING IF ASKED."
	OS.shell_open(_apk_url)
	_set_buttons([["DOWNLOAD AGAIN", _browser_download], ["QUIT", _quit]])


# ---------------------------------------------------------------- ANDROID DOWNLOAD
func _android_ready() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton("AndroidRuntime")


func _activity() -> Variant:
	var rt = Engine.get_singleton("AndroidRuntime")
	if rt == null:
		return null
	return rt.getActivity()


## Folder where the APK is stored (the app's own external folder, no storage permission needed).
func _downloads_dir(activity: Variant) -> String:
	var dir = activity.getExternalFilesDir("Download")
	if dir == null:
		return ""
	return str(dir.getAbsolutePath())


## Starts the download with the Android DownloadManager. Returns false when that is not possible.
func _begin_download() -> bool:
	var activity = _activity()
	if activity == null:
		return false
	_dm = activity.getSystemService("download")
	if _dm == null:
		return false
	_dl_dir = _downloads_dir(activity)
	if _dl_dir == "":
		return false
	_cleanup_downloads()

	var Uri = JavaClassWrapper.wrap("android.net.Uri")
	var Request = JavaClassWrapper.wrap("android.app.DownloadManager$Request")
	if Uri == null or Request == null:
		return false
	var file_name := "SuperPixelBros-%s.apk" % _clean_tag(_remote_tag)
	_dl_path = _dl_dir.path_join(file_name)
	var req = Request.Request(Uri.parse(_apk_url))
	req.setTitle("Super Pixel Bros")
	req.setDescription("Update V" + _clean_tag(_remote_tag))
	req.setMimeType(APK_MIME)
	req.setNotificationVisibility(1) # VISIBILITY_VISIBLE while downloading
	req.setDestinationInExternalFilesDir(activity, "Download", file_name)
	_dl_id = int(_dm.enqueue(req))
	if _dl_id < 0:
		return false

	_step = Step.DOWNLOADING
	_poll_t = 0.0
	_stall_t = 0.0
	_last_got = 0
	_apk_uri = null
	_set_buttons([])
	_title.text = "DOWNLOADING"
	_info.text = "PLEASE DO NOT CLOSE\nTHE GAME.\n\n0%"
	_bar_fill.size.x = 0
	_bar_bg.visible = true
	return true


func _process(delta: float) -> void:
	if _step != Step.DOWNLOADING or _dl_id < 0:
		return
	_poll_t += delta
	if _poll_t < 0.4:
		return
	var dt := _poll_t
	_poll_t = 0.0

	var st := _dm_poll()
	var status := 0
	var got := 0
	var total := _asset_size
	if st["ok"]:
		status = int(st["status"])
		got = int(st["got"])
		if int(st["total"]) > 0:
			total = int(st["total"])
	else:
		# The status query is not available: measure the file and ask for the finished download.
		got = _file_len(_dl_path)
		if _dm.getUriForDownloadedFile(_dl_id) != null:
			status = DM_STATUS_SUCCESSFUL

	if got > _last_got:
		_last_got = got
		_stall_t = 0.0
	else:
		_stall_t += dt
	_show_progress(got, total)

	if status == DM_STATUS_SUCCESSFUL:
		_download_done()
	elif status == DM_STATUS_FAILED:
		_download_failed("THE DOWNLOAD FAILED.")
	elif _stall_t > STALL_SECONDS:
		_download_failed("THE DOWNLOAD STOPPED.")


## Reads the state of the download: {ok, status, got, total}.
func _dm_poll() -> Dictionary:
	var out := {"ok": false, "status": 0, "got": 0, "total": 0}
	var Query = JavaClassWrapper.wrap("android.app.DownloadManager$Query")
	if Query == null:
		return out
	var q = Query.Query()
	q.setFilterById(PackedInt64Array([_dl_id]))
	var c = _dm.query(q)
	if c == null:
		return out
	if c.moveToFirst():
		out["status"] = int(c.getInt(c.getColumnIndex("status")))
		out["got"] = int(c.getLong(c.getColumnIndex("bytes_so_far")))
		out["total"] = int(c.getLong(c.getColumnIndex("total_size")))
		out["ok"] = true
	c.close()
	return out


func _show_progress(got: int, total: int) -> void:
	var frac := 0.0
	if total > 0:
		frac = clampf(float(got) / float(total), 0.0, 1.0)
	_bar_fill.size.x = floorf((BAR_W - 4.0) * frac)
	var txt := "%.1f MB" % (got / 1048576.0)
	if total > 0:
		txt = "%d%%\n%.1f / %.1f MB" % [int(frac * 100.0), got / 1048576.0, total / 1048576.0]
	_info.text = "PLEASE DO NOT CLOSE\nTHE GAME.\n\n" + txt


func _file_len(path: String) -> int:
	if path == "" or not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var n := f.get_length()
	f.close()
	return n


func _download_done() -> void:
	_apk_uri = _dm.getUriForDownloadedFile(_dl_id)
	if _apk_uri == null:
		_download_failed("THE DOWNLOADED FILE WAS NOT FOUND.")
		return
	if not _verify_apk():
		_remove_download_file()
		_download_failed("THE DOWNLOADED FILE IS\nINCOMPLETE OR DAMAGED.")
		return
	_step = Step.READY
	_bar_fill.size.x = BAR_W - 4.0
	_title.text = "DOWNLOAD COMPLETE"
	_info.text = "TAP INSTALL NOW, THEN\nCONFIRM IN THE ANDROID\nDIALOG."
	_set_buttons([["INSTALL NOW", _install_now], ["QUIT", _quit]])


## Checks size and SHA-256 when the file can be read (skipped when it cannot).
func _verify_apk() -> bool:
	if _file_len(_dl_path) == 0:
		return true
	if _asset_size > 0 and _file_len(_dl_path) != _asset_size:
		return false
	if _asset_digest.begins_with("sha256:"):
		var want := _asset_digest.trim_prefix("sha256:").to_lower()
		if FileAccess.get_sha256(_dl_path).to_lower() != want:
			return false
	return true


func _download_failed(reason: String) -> void:
	_step = Step.ERROR
	_remove_download_entry()
	_bar_bg.visible = false
	_title.text = "DOWNLOAD FAILED"
	_info.text = reason + "\n\nCHECK YOUR INTERNET\nCONNECTION AND TRY AGAIN."
	_set_buttons([["TRY AGAIN", _start_update], ["DOWNLOAD VIA BROWSER", _browser_download], ["QUIT", _quit]])


# ---------------------------------------------------------------- ANDROID INSTALL
## Opens the Android installer for the downloaded APK.
func _install_now() -> void:
	var activity = _activity()
	if activity == null or _apk_uri == null:
		_browser_download()
		return
	var Intent = JavaClassWrapper.wrap("android.content.Intent")
	var Uri = JavaClassWrapper.wrap("android.net.Uri")
	var Version = JavaClassWrapper.wrap("android.os.Build$VERSION")
	if Intent == null or Uri == null or Version == null:
		_browser_download()
		return

	# Android 8+: the player must first allow this app to install other apps.
	if int(Version.SDK_INT) >= 26 and not activity.getPackageManager().canRequestPackageInstalls():
		var settings = Intent.Intent("android.settings.MANAGE_UNKNOWN_APP_SOURCES")
		settings.setData(Uri.parse("package:" + str(activity.getPackageName())))
		activity.startActivity(settings)
		_info.text = "TURN ON ALLOW FROM\nTHIS SOURCE, GO BACK TO\nTHE GAME, THEN TAP\nINSTALL NOW."
		return

	var intent = Intent.Intent("android.intent.action.VIEW")
	intent.setDataAndType(_apk_uri, APK_MIME)
	intent.addFlags(FLAG_GRANT_READ_URI_PERMISSION | FLAG_ACTIVITY_NEW_TASK)
	activity.startActivity(intent)
	_info.text = "CONFIRM THE INSTALL IN THE\nANDROID DIALOG. IF NOTHING\nHAPPENS, USE THE BROWSER\nDOWNLOAD."
	_set_buttons([["INSTALL AGAIN", _install_now], ["DOWNLOAD VIA BROWSER", _browser_download], ["QUIT", _quit]])


# ---------------------------------------------------------------- CLEANUP
func _remove_download_entry() -> void:
	if _dm == null or _dl_id < 0:
		return
	_dm.remove(PackedInt64Array([_dl_id]))
	_dl_id = -1


func _remove_download_file() -> void:
	if _dl_path != "" and FileAccess.file_exists(_dl_path):
		DirAccess.remove_absolute(_dl_path)


## Deletes APK files from earlier downloads (they are ~100 MB each).
func _cleanup_downloads() -> void:
	if not _android_ready():
		return
	var activity = _activity()
	if activity == null:
		return
	var dir := _downloads_dir(activity)
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		if f.to_lower().ends_with(".apk"):
			DirAccess.remove_absolute(dir.path_join(f))
