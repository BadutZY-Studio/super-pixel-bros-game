extends CanvasLayer
## In-game HUD + overlay panels (intro card, pause, course clear, game over).

var level
var score_l: Label
var coins_l: Label
var time_l: Label
var lives_l: Label
var world_l: Label
var overlay: Control
var paused := false
var pause_root: Control

var bar_root: Control
var time_bar: ColorRect
var coin_icon: AnimatedSprite2D
var lives_icon: TextureRect
var max_time := 0.0
var _shown_score := 0.0
var _last_coins := -1
var _last_lives := -1
var _bar_shown := false
var _flash := {}


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	bar_root = Control.new()
	bar_root.size = Vector2(400, 28)
	bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.position = Vector2(0, -32)
	add_child(bar_root)

	# translucent gradient bar + gold rule + time track
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.03, 0.14, 0.92))
	g.set_color(1, Color(0.04, 0.05, 0.20, 0.62))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 24
	var bg := TextureRect.new()
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(400, 24)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(bg)
	var line := ColorRect.new()
	line.color = Color(1, 0.82, 0.2, 0.9)
	line.position = Vector2(0, 24)
	line.size = Vector2(400, 1)
	bar_root.add_child(line)
	var track := ColorRect.new()
	track.color = Color(0, 0, 0, 0.45)
	track.position = Vector2(0, 25)
	track.size = Vector2(400, 2)
	bar_root.add_child(track)
	time_bar = ColorRect.new()
	time_bar.color = Color(0.4, 1.0, 0.5)
	time_bar.position = Vector2(0, 25)
	time_bar.size = Vector2(400, 2)
	bar_root.add_child(time_bar)
	# thin separators between groups
	for x in [82, 160, 228, 308]:
		var sep := ColorRect.new()
		sep.color = Color(1, 1, 1, 0.12)
		sep.position = Vector2(x, 4)
		sep.size = Vector2(1, 16)
		bar_root.add_child(sep)

	_title("SCORE", 8)
	score_l = _value(8)
	_title("COINS", 92)
	coin_icon = AnimatedSprite2D.new()
	coin_icon.sprite_frames = Game.make_frames(Game.tex("res://assets/sprites/coin.png"), 16, 16, {
		"spin": {"frames": [0, 1, 2, 3], "fps": 6, "loop": true}})
	coin_icon.centered = false
	coin_icon.position = Vector2(88, 9)
	coin_icon.scale = Vector2(0.875, 0.875)
	coin_icon.play("spin")
	bar_root.add_child(coin_icon)
	coins_l = _value(104)
	_title("WORLD", 168)
	world_l = _value(168)
	world_l.text = Game.level_label(Game.current_level)
	_title("TIME", 236)
	time_l = _value(236)
	_title("LIVES", 320)
	lives_icon = TextureRect.new()
	lives_icon.texture = Game.Cosmetics.life_icon(Game.loadout)
	lives_icon.position = Vector2(318, 9)
	lives_icon.size = Vector2(14, 14)
	lives_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lives_icon.stretch_mode = TextureRect.STRETCH_SCALE
	bar_root.add_child(lives_icon)
	lives_l = _value(334)
	# safety net: if no intro card runs, still show the bar
	get_tree().create_timer(3.0).timeout.connect(_slide_in_bar)


func _slide_in_bar() -> void:
	if _bar_shown or not is_instance_valid(bar_root):
		return
	_bar_shown = true
	var tw := bar_root.create_tween()
	tw.tween_property(bar_root, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _title(text: String, x: float) -> void:
	var l := UI.label(text, 8, Color(1.0, 0.82, 0.25))
	l.position = Vector2(x, 2)
	bar_root.add_child(l)


func _value(x: float) -> Label:
	var l := UI.label("", 8, Color.WHITE)
	l.position = Vector2(x, 12)
	bar_root.add_child(l)
	return l


## Little hop + colour flash on a HUD value when it changes.
func _bump(l: Label, color: Color = Color(1.0, 0.95, 0.4)) -> void:
	var key := l.get_instance_id()
	if _flash.has(key) and _flash[key] and _flash[key].is_valid():
		_flash[key].kill()
	l.position.y = 12.0
	l.add_theme_color_override("font_color", color)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", 9.0, 0.06)
	tw.tween_property(l, "position:y", 12.0, 0.10).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): l.add_theme_color_override("font_color", Color.WHITE))
	_flash[key] = tw


func _process(delta: float) -> void:
	if level == null:
		return
	if max_time <= 0.0:
		max_time = maxf(float(level.data["time"]), 1.0) if level.data.has("time") else maxf(level.time_left, 1.0)
	# rolling score counter
	var target := float(Game.score)
	if absf(target - _shown_score) < 1.0:
		_shown_score = target
	else:
		_shown_score = lerpf(_shown_score, target, clampf(delta * 12.0, 0.0, 1.0))
	score_l.text = UI.score_text(int(round(_shown_score)))
	coins_l.text = "x" + str(Game.coins).pad_zeros(2)
	if _last_coins != -1 and Game.coins != _last_coins:
		_bump(coins_l)
		coin_icon.speed_scale = 4.0
		var ct := coin_icon.create_tween()
		ct.tween_interval(0.35)
		ct.tween_callback(func(): coin_icon.speed_scale = 1.0)
	_last_coins = Game.coins
	lives_l.text = "x" + str(Game.lives)
	if _last_lives != -1 and Game.lives != _last_lives:
		_bump(lives_l, Color(0.6, 1.0, 0.7) if Game.lives > _last_lives else Color(1.0, 0.45, 0.4))
		var tw := lives_icon.create_tween()
		tw.tween_property(lives_icon, "position:y", 4.0, 0.08)
		tw.tween_property(lives_icon, "position:y", 9.0, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_last_lives = Game.lives
	var t := int(ceil(level.time_left))
	time_l.text = str(t).pad_zeros(3)
	var frac := clampf(level.time_left / max_time, 0.0, 1.0)
	time_bar.size.x = 400.0 * frac
	var tc := Color(0.4, 1.0, 0.5).lerp(Color(1.0, 0.85, 0.2), clampf((0.6 - frac) / 0.3, 0.0, 1.0))
	tc = tc.lerp(Color(1.0, 0.3, 0.3), clampf((0.3 - frac) / 0.2, 0.0, 1.0))
	time_bar.color = tc
	if t <= 100 and level.running:
		var on := (Time.get_ticks_msec() / 250) % 2 == 0
		time_l.add_theme_color_override("font_color", Color(1, 0.3, 0.3) if on else Color.WHITE)
		time_bar.modulate.a = 1.0 if on else 0.55


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and level != null and level.running and not level.finished and not level.player.dead:
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif paused and event.is_action_pressed("ui_cancel"):
		_resume()  # B on a controller closes the pause menu
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ helpers
func _fullscreen_dim(alpha: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.01, 0.01, 0.08, alpha)
	r.size = Vector2(400, 224)
	return r


func _center(child: Control) -> Control:
	var cc := CenterContainer.new()
	cc.size = Vector2(400, 224)
	cc.add_child(child)
	return cc


func _clear_overlay() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func _heading(text: String, color: Color) -> Label:
	var l := UI.label(text, 16, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _rule() -> ColorRect:
	var sep := ColorRect.new()
	sep.color = Color(1.0, 0.82, 0.2, 0.35)
	sep.custom_minimum_size = Vector2(0, 1)
	return sep


## Stat row: name on the left, value on the right. Returns the value label.
func _stat_row(parent: Control, name_text: String, color: Color = Color.WHITE) -> Label:
	var hb := HBoxContainer.new()
	var n := UI.label(name_text, 8, Color(0.75, 0.85, 1.0))
	hb.add_child(n)
	var v := UI.label("", 8, color)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(v)
	parent.add_child(hb)
	return v


# ------------------------------------------------------------------ intro card
func show_intro() -> void:
	var th: Dictionary = Game.LevelsData.THEMES[level.data["theme"]]
	var root := Control.new()
	root.size = Vector2(400, 224)
	add_child(root)
	root.add_child(Game.make_sky(th["sky_top"].darkened(0.6), th["sky_bot"].darkened(0.45)))
	var dust := UI.particles(Vector2(8, 100), Color(1, 1, 1, 0.8), 22, 2.2, Vector2(0, -1), Vector2.ZERO, 1.5)
	dust.position = Vector2(404, 112)
	dust.direction = Vector2(-1, 0)
	dust.spread = 8.0
	dust.initial_velocity_min = 80.0
	dust.initial_velocity_max = 160.0
	root.add_child(dust)
	root.add_child(UI.vignette(0.6))
	var idx: int = Game.current_level
	var rb := UI.ribbon_centered("WORLD " + Game.level_label(idx), 54)
	root.add_child(rb)
	var t2 := UI.wide_label(str(level.data["name"]), 16, Color.WHITE, 90)
	root.add_child(t2)
	var ch_l := UI.wide_label("%s  -  LEVEL %d" % [str(Game.CHAPTERS[Game.chapter_of(idx)]["name"]), Game.level_in_chapter(idx)], 8, UI.GOLD, 36)
	root.add_child(ch_l)
	# lives row: [icon] x 3  -- one centred HBox so it is always symmetric
	var row := Control.new()
	row.position = Vector2(0, 124)
	row.size = Vector2(400, 20)
	root.add_child(row)
	var hb := HBoxContainer.new()
	hb.size = Vector2(400, 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	row.add_child(hb)
	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(16, 20)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(icon_box)
	var li := TextureRect.new()
	li.texture = Game.Cosmetics.life_icon(Game.loadout)
	li.position = Vector2(0, 2)
	icon_box.add_child(li)
	var tx := UI.label("x", 16, Color.WHITE)
	tx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(tx)
	var tn := UI.label(str(Game.lives), 16, Color.WHITE)
	tn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(tn)
	var ready_l := UI.wide_label("GET READY!", 8, UI.MINT, 168)
	root.add_child(ready_l)
	# entrance
	UI.slide_in(rb, Vector2(-260, 0), 0.0, 0.5, Tween.TRANS_CUBIC)
	UI.slide_in(t2, Vector2(260, 0), 0.12, 0.5, Tween.TRANS_CUBIC)
	UI.pop_in(row, 0.3, 0.3)
	var hop := li.create_tween().set_loops()
	hop.tween_interval(0.25)
	hop.tween_property(li, "position:y", -3.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop.tween_property(li, "position:y", 2.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	hop.tween_interval(0.35)
	var blink := ready_l.create_tween().set_loops()
	blink.tween_property(ready_l, "modulate:a", 0.25, 0.3)
	blink.tween_property(ready_l, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer(1.7).timeout
	_slide_in_bar()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "modulate:a", 0.0, 0.3)
	tw.tween_property(rb, "position:y", rb.position.y - 12.0, 0.3)
	tw.tween_property(t2, "position:y", t2.position.y + 12.0, 0.3)
	await tw.finished
	root.queue_free()


# ------------------------------------------------------------------ pause
func toggle_pause() -> void:
	if paused:
		_resume()
		return
	paused = true
	get_tree().paused = true
	Audio.play("click")
	pause_root = Control.new()
	pause_root.size = Vector2(400, 224)
	add_child(pause_root)
	var dim := _fullscreen_dim(0.6)
	pause_root.add_child(dim)
	UI.fade_in(dim, 0.0, 0.15)
	var p := UI.panel(Vector2(200, 0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	p.add_child(vb)
	vb.add_child(_heading("PAUSED", Color(1.0, 0.85, 0.25)))
	vb.add_child(_rule())
	var first := UI.button("RESUME", _resume, 176)
	vb.add_child(first)
	vb.add_child(UI.slider("MUSIC", func(): return Game.music_volume, func(v: float):
		Game.music_volume = v
		Audio.update_volumes()
		Game.save_game(), 176))
	vb.add_child(UI.slider("SOUND", func(): return Game.sfx_volume, func(v: float):
		Game.sfx_volume = v
		Game.save_game(), 176))
	vb.add_child(UI.button("RESTART LEVEL", func():
		Game.new_run(Game.current_level)
		UI.go("res://scenes/level.tscn"), 176))
	vb.add_child(UI.button("LEVEL SELECT", func(): UI.go("res://scenes/level_select.tscn"), 176))
	vb.add_child(UI.button("MAIN MENU", func(): UI.go("res://scenes/menu.tscn"), 176))
	pause_root.add_child(_center(p))
	UI.pop_in(p, 0.0, 0.22)
	first.call_deferred("grab_focus")


func _resume() -> void:
	paused = false
	get_tree().paused = false
	if pause_root:
		pause_root.queue_free()
		pause_root = null


# ------------------------------------------------------------------ course clear
func show_complete(time_bonus: int) -> void:
	var root := Control.new()
	root.size = Vector2(400, 224)
	add_child(root)
	overlay = root
	var dim := _fullscreen_dim(0.0)
	root.add_child(dim)
	var dt := create_tween()
	dt.tween_property(dim, "color:a", 0.6, 0.35)
	var last: bool = not Game.has_next_level()
	var p := UI.panel(Vector2(250, 0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	p.add_child(vb)
	var chapter_end: bool = (Game.current_level % 10 == 9)
	var heading_text := "COURSE CLEAR!"
	if last:
		heading_text = "YOU WIN!"
	elif chapter_end:
		heading_text = "CHAPTER %d CLEAR!" % (Game.chapter_of(Game.current_level) + 1)
	var title := _heading(heading_text, Color(1.0, 0.85, 0.25))
	vb.add_child(title)
	if last:
		var thanks := UI.label("THANKS FOR PLAYING!", 8, UI.MINT)
		thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(thanks)
	vb.add_child(_rule())
	var time_row := _stat_row(vb, "TIME BONUS")
	var coin_row := _stat_row(vb, "COINS")
	coin_row.text = "x%d" % Game.coins
	var shop_row := _stat_row(vb, "SHOP COINS", Color(1.0, 0.85, 0.3))
	var score_row := _stat_row(vb, "SCORE", Color(1.0, 0.95, 0.5))
	var best_row := _stat_row(vb, "BEST", Color(0.7, 0.8, 1.0))
	root.add_child(_center(p))
	UI.pop_in(p, 0.15, 0.35)
	# celebration
	UI.burst(root, Vector2(90, 20), 36, 150.0)
	UI.burst(root, Vector2(310, 20), 36, 150.0)
	await get_tree().create_timer(0.2).timeout
	UI.burst(root, Vector2(200, 10), 44, 170.0)
	var t := int(level.time_left)
	var gained := 0
	score_row.text = UI.score_text(Game.score)
	while t > 0:
		var step := mini(t, 2)
		t -= step
		gained += 50 * step
		Game.score += 50 * step
		time_row.text = "%03d  +%d" % [t, gained]
		score_row.text = UI.score_text(Game.score)
		Audio.play("tick")
		await get_tree().create_timer(0.02).timeout
	time_row.text = "+%d" % gained
	time_row.add_theme_color_override("font_color", UI.MINT)
	score_row.text = UI.score_text(Game.score)
	var prev_best := Game.best_for(Game.current_level)
	Game.complete_level(Game.score)   # also pays the course-clear bonus into the shop wallet and saves
	shop_row.text = "+%d" % Game.run_earned
	if Game.score > prev_best and prev_best > 0:
		best_row.text = "NEW BEST!"
		best_row.add_theme_color_override("font_color", UI.GOLD)
		var bl := best_row.create_tween().set_loops()
		bl.tween_property(best_row, "modulate:a", 0.3, 0.25)
		bl.tween_property(best_row, "modulate:a", 1.0, 0.25)
		UI.burst(root, Vector2(200, 60), 30, 130.0)
		Audio.play("oneup")
	else:
		best_row.text = UI.score_text(Game.best_for(Game.current_level))
	await get_tree().create_timer(0.5).timeout
	vb.add_child(_rule())
	var first: Button
	if not last:
		first = UI.button("NEXT CHAPTER" if chapter_end else "NEXT LEVEL", func():
			Game.go_next_level()
			UI.go("res://scenes/level.tscn"), 226)
		vb.add_child(first)
	else:
		first = UI.button("MAIN MENU", func(): UI.go("res://scenes/menu.tscn"), 226)
		vb.add_child(first)
	var replay := UI.button("PLAY AGAIN", func():
		var keep_lives := 3
		Game.new_run(Game.current_level)
		Game.lives = keep_lives
		UI.go("res://scenes/level.tscn"), 226)
	vb.add_child(replay)
	if not last:
		vb.add_child(UI.button("LEVEL SELECT", func(): UI.go("res://scenes/level_select.tscn"), 226))
	UI.pop_in(first, 0.0, 0.2)
	UI.pop_in(replay, 0.06, 0.2)
	first.grab_focus()


# ------------------------------------------------------------------ game over
func show_gameover() -> void:
	Game.flush_wallet()
	var root := Control.new()
	root.size = Vector2(400, 224)
	add_child(root)
	overlay = root
	var dim := _fullscreen_dim(0.0)
	root.add_child(dim)
	var vg := UI.vignette(0.0)
	vg.texture.gradient.set_color(1, Color(0.55, 0.02, 0.05, 0.8))
	root.add_child(vg)
	vg.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "color:a", 0.8, 0.6)
	tw.tween_property(vg, "modulate:a", 1.0, 0.8)
	await tw.finished
	var p := UI.panel(Vector2(220, 0), UI.RED)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	p.add_child(vb)
	var title := _heading("GAME OVER", Color(1.0, 0.35, 0.3))
	vb.add_child(title)
	var flick := title.create_tween().set_loops(3)
	flick.tween_property(title, "modulate", Color(1, 1, 1, 0.35), 0.12)
	flick.tween_property(title, "modulate", Color.WHITE, 0.12)
	vb.add_child(_rule())
	var sc := _stat_row(vb, "SCORE", Color(1.0, 0.95, 0.5))
	sc.text = UI.score_text(Game.score)
	var sh := _stat_row(vb, "SHOP COINS", Color(1.0, 0.85, 0.3))
	sh.text = "+%d" % Game.run_earned
	var first := UI.button("TRY AGAIN", func():
		Game.new_run(Game.current_level)
		UI.go("res://scenes/level.tscn"), 196)
	vb.add_child(first)
	vb.add_child(UI.button("LEVEL SELECT", func(): UI.go("res://scenes/level_select.tscn"), 196))
	vb.add_child(UI.button("MAIN MENU", func(): UI.go("res://scenes/menu.tscn"), 196))
	root.add_child(_center(p))
	UI.pop_in(p, 0.0, 0.3)
	first.grab_focus()
