extends Node
## Sound effects pool + looping music (autoload "Audio").

var _sfx_players: Array = []
var _music: AudioStreamPlayer
var _current_track := ""
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music.finished.connect(_on_music_finished)


func _load(path: String) -> AudioStream:
	if not _cache.has(path):
		if ResourceLoader.exists(path):
			_cache[path] = load(path)
		else:
			_cache[path] = null
	return _cache[path]


func play(sfx_name: String, pitch: float = 1.0) -> void:
	var s := _load("res://assets/audio/sfx_%s.wav" % sfx_name)
	if s == null or Game.sfx_volume <= 0.001:
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = s
			p.pitch_scale = pitch
			p.volume_db = linear_to_db(Game.sfx_volume)
			p.play()
			return


func play_music(track: String) -> void:
	if track == _current_track and _music.playing:
		return
	var s := _load("res://assets/audio/music_%s.wav" % track)
	_current_track = track
	if s == null:
		_music.stop()
		return
	_music.stream = s
	_music.volume_db = linear_to_db(maxf(Game.music_volume * 0.55, 0.0001))
	_music.play()


func stop_music() -> void:
	_current_track = ""
	_music.stop()


func update_volumes() -> void:
	if _music:
		_music.volume_db = linear_to_db(maxf(Game.music_volume * 0.55, 0.0001))


func _on_music_finished() -> void:
	if _current_track != "":
		_music.play()
