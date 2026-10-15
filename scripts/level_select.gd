extends Control
## Level selection grid (5 x 2) with themed previews, medals and a details bar.

const ScrollerScript = preload("res://scripts/scroller.gd")
const CARD := Vector2(70, 66)

var name_l: Label
var best_l: Label
var cards: Array = []
var chapter := 0                 # which chapter is shown (10 levels each)
var grid: GridContainer
var title: Control
var back_btn: Button
var prev_btn: Button
var next_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.play_music("menu")
	var th: Dictionary = Game.LevelsData.THEMES["night"]
	add_child(Game.make_sky(th["sky_top"], th["sky_bot"]))
	_twinkle()
	var st = ScrollerScript.new()
	add_child(st)
	st.setup(Game.tex("res://assets/bg/bg_night_sky.png"), 1.0, 180.0, 5.0)
	var far = ScrollerScript.new()
	add_child(far)
	far.setup(Game.tex("res://assets/bg/bg_night_far.png"), 1.0, 224.0, 8.0)
	add_child(UI.vignette(0.5))

	var focus_idx: int = clampi(Game.unlocked - 1, 0, Game.level_count() - 1)
	chapter = Game.chapter_of(focus_idx)

	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.position = Vector2(200 - (5 * CARD.x + 4 * 6) * 0.5, 38)
	add_child(grid)

	# details bar under the grid
	var bar := Control.new()
	bar.position = Vector2(200 - (5 * CARD.x + 4 * 6) * 0.5, 178)
	bar.size = Vector2(5 * CARD.x + 4 * 6, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		bar.draw_rect(Rect2(0, 0, bar.size.x, bar.size.y), Color(0.03, 0.04, 0.16, 0.8))
		bar.draw_rect(Rect2(0, 0, bar.size.x, bar.size.y), Color(1.0, 0.82, 0.2, 0.6), false, 1.0))
	add_child(bar)
	name_l = UI.label("", 8, Color.WHITE)
	name_l.position = Vector2(6, 3)
	bar.add_child(name_l)
	best_l = UI.label("", 8, UI.MINT)
	best_l.position = Vector2(bar.size.x - 6 - 12 * 8, 3)
	best_l.size = Vector2(12 * 8, 8)
	best_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(best_l)
	UI.fade_in(bar, 0.4, 0.3)

	var back := UI.button("BACK", func(): UI.go("res://scenes/menu.tscn"), 90)
	back.position = Vector2(155, 198)
	add_child(back)
	UI.pop_in(back, 0.5, 0.25)
	back_btn = back

	# chapter switch: [<] CHAPTER N [>]   (also Q / E, or LB / RB on a controller)
	prev_btn = UI.compact_button("<", func(): _switch_chapter(-1), 54)
	prev_btn.position = Vector2(8, 10)
	add_child(prev_btn)
	next_btn = UI.compact_button(">", func(): _switch_chapter(1), 54)
	next_btn.position = Vector2(338, 10)
	add_child(next_btn)
	_set_title(false)
	_fill_grid()
	var first_card: int = focus_idx - chapter * 10
	if first_card >= 0 and first_card < cards.size():
		cards[first_card].call_deferred("grab_focus")
		_show_info(focus_idx)

	var total := 0
	var cleared := 0
	for k in Game.best_scores:
		total += int(Game.best_scores[k])
		if int(Game.best_scores[k]) > 0:
			cleared += 1
	var tl := UI.label("TOTAL BEST", 8, Color(0.75, 0.85, 1.0))
	tl.position = Vector2(8, 200)
	add_child(tl)
	var tv := UI.label(UI.score_text(total, 7), 8, UI.GOLD)
	tv.position = Vector2(8, 211)
	add_child(tv)
	var cl := UI.label("CLEARED", 8, Color(0.75, 0.85, 1.0))
	cl.position = Vector2(400 - 8 - 7 * 8, 200)
	add_child(cl)
	var cv := UI.label("%d/%d" % [cleared, Game.level_count()], 8, UI.MINT)
	cv.position = Vector2(400 - 8 - 7 * 8, 211)
	add_child(cv)


## Back to the title with B (controller), ESC or the pause key.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		UI.go("res://scenes/menu.tscn")
		get_viewport().set_input_as_handled()
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.physical_keycode == KEY_Q:
			_switch_chapter(-1)
		elif k.physical_keycode == KEY_E:
			_switch_chapter(1)
		return
	var jb := event as InputEventJoypadButton
	if jb != null and jb.pressed:
		if jb.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_switch_chapter(-1)
		elif jb.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_switch_chapter(1)


## Chapter title ribbon at the top.
func _set_title(animate: bool) -> void:
	if title != null and is_instance_valid(title):
		title.queue_free()
	var ch: Dictionary = Game.CHAPTERS[chapter]
	title = UI.ribbon_centered(str(ch["name"]), 8)
	_ignore_mouse(title)          # the full-width title container must never swallow clicks meant for the < > buttons meant for the < > buttons
	add_child(title)
	if animate:
		UI.pop_in(title, 0.0, 0.2)
	else:
		UI.slide_in(title, Vector2(0, -30), 0.0, 0.45)
	if prev_btn != null:
		var has_prev: bool = chapter > 0
		var has_next: bool = chapter < Game.CHAPTERS.size() - 1
		prev_btn.text = "< CH %d" % chapter if has_prev else "<"
		next_btn.text = "CH %d >" % (chapter + 2) if has_next else ">"
		prev_btn.modulate.a = 1.0 if has_prev else 0.35
		next_btn.modulate.a = 1.0 if has_next else 0.35


## Makes a node and all its children transparent to the mouse / touch.
func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


func _switch_chapter(d: int) -> void:
	var n := clampi(chapter + d, 0, Game.CHAPTERS.size() - 1)
	if n == chapter:
		Audio.play("bump")
		return
	chapter = n
	Audio.play("select")
	_set_title(true)
	_fill_grid()
	var want: int = clampi(Game.unlocked - 1 - chapter * 10, 0, cards.size() - 1)
	cards[want].call_deferred("grab_focus")


## (Re)builds the 5 x 2 grid for the current chapter.
func _fill_grid() -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	cards.clear()
	var ch: Dictionary = Game.CHAPTERS[chapter]
	for k in int(ch["count"]):
		var b := _card(int(ch["first"]) + k)
		grid.add_child(b)
		cards.append(b)
	if cards.size() > 5:
		UI.wire_focus_grid([[prev_btn, next_btn], cards.slice(0, 5), cards.slice(5), [back_btn]])
		prev_btn.focus_neighbor_bottom = prev_btn.get_path_to(cards[0])
		next_btn.focus_neighbor_bottom = next_btn.get_path_to(cards[4])
		prev_btn.focus_neighbor_right = prev_btn.get_path_to(next_btn)
		next_btn.focus_neighbor_left = next_btn.get_path_to(prev_btn)
		cards[0].focus_neighbor_top = cards[0].get_path_to(prev_btn)
		for i in range(1, 4):
			cards[i].focus_neighbor_top = cards[i].get_path_to(prev_btn if i < 3 else next_btn)
		cards[4].focus_neighbor_top = cards[4].get_path_to(next_btn)
		back_btn.focus_neighbor_top = back_btn.get_path_to(cards[7])


func _twinkle() -> void:
	var stars := UI.particles(Vector2(200, 80), Color(1, 1, 0.9, 1), 34, 2.4, Vector2(0, -1), Vector2.ZERO, 1.0)
	stars.position = Vector2(200, 90)
	stars.initial_velocity_min = 0.0
	stars.initial_velocity_max = 2.0
	add_child(stars)


func _show_info(i: int) -> void:
	var data: Dictionary = Game.LevelsData.DATA[i]
	var locked: bool = i >= Game.unlocked
	name_l.text = (Game.level_label(i) + " " + str(data["name"])) if not locked else (Game.level_label(i) + " ???")
	name_l.add_theme_color_override("font_color", Color(0.6, 0.6, 0.68) if locked else Color.WHITE)
	var best := Game.best_for(i)
	best_l.text = ("LOCKED" if locked else ("BEST " + str(best) if best > 0 else "NEW!"))
	best_l.add_theme_color_override("font_color", Color(0.9, 0.5, 0.45) if locked else (UI.MINT if best > 0 else UI.GOLD))


func _card(i: int) -> Button:
	var data: Dictionary = Game.LevelsData.DATA[i]
	var th: Dictionary = Game.LevelsData.THEMES[data["theme"]]
	var locked: bool = i >= Game.unlocked
	var best := Game.best_for(i)
	var b := Button.new()
	b.custom_minimum_size = CARD
	b.focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	# hard shadow stays on the button, the face lifts when selected
	b.draw.connect(func():
		b.draw_rect(Rect2(2, 3, CARD.x, CARD.y), Color(0, 0, 0, 0.4)))
	var face := Control.new()
	face.size = CARD
	face.pivot_offset = CARD * 0.5
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(face)
	var st := {"pulse": 0.0, "tw": null}
	face.draw.connect(func():
		var focused := b.has_focus()
		var border := Color(0.06, 0.06, 0.16)
		if focused:
			border = UI.GOLD.lerp(Color.WHITE, st["pulse"] * 0.7)
		elif locked:
			border = Color(0.16, 0.16, 0.22)
		face.draw_rect(Rect2(0, 0, CARD.x, CARD.y), Color(0.07, 0.08, 0.26) if not locked else Color(0.10, 0.10, 0.16))
		face.draw_rect(Rect2(0, 0, CARD.x, CARD.y), border, false, 2.0)
		face.draw_rect(Rect2(2, 2, CARD.x - 4, 1), Color(1, 1, 1, 0.12))
		if focused:
			for c in [Vector2(0, 0), Vector2(CARD.x - 4, 0), Vector2(0, CARD.y - 4), Vector2(CARD.x - 4, CARD.y - 4)]:
				face.draw_rect(Rect2(c.x, c.y, 4, 4), border))
	# themed mini landscape
	var prev := Control.new()
	prev.position = Vector2(4, 4)
	prev.size = Vector2(62, 26)
	prev.clip_contents = true
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(prev)
	var sky := TextureRect.new()
	sky.texture = _gradient(th)
	sky.size = Vector2(62, 26)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prev.add_child(sky)
	var far_path := "res://assets/bg/bg_%s_far.png" % data["theme"]
	if ResourceLoader.exists(far_path):
		var far := TextureRect.new()
		far.texture = Game.tex(far_path)
		far.position = Vector2(-96, -58)
		far.size = Vector2(256, 128)
		far.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prev.add_child(far)
	var ground := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = Game.tex("res://assets/tiles/tiles_%s.png" % data["theme"])
	at.region = Rect2(0, 0, 16, 7)
	ground.texture = at
	ground.stretch_mode = TextureRect.STRETCH_TILE
	ground.position = Vector2(0, 19)
	ground.size = Vector2(62, 7)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prev.add_child(ground)
	if locked:
		var shade := ColorRect.new()
		shade.color = Color(0.04, 0.04, 0.1, 0.72)
		shade.size = Vector2(62, 26)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prev.add_child(shade)
	# padlock / medal drawn above the preview
	var badge := Control.new()
	badge.size = CARD
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(badge)
	badge.draw.connect(func():
		if locked:
			var cx := 35.0
			var cy := 17.0
			var steel := Color(0.78, 0.80, 0.90)
			badge.draw_rect(Rect2(cx - 4, cy - 9, 8, 2), steel)
			badge.draw_rect(Rect2(cx - 4, cy - 9, 2, 6), steel)
			badge.draw_rect(Rect2(cx + 2, cy - 9, 2, 6), steel)
			badge.draw_rect(Rect2(cx - 6, cy - 4, 12, 9), UI.GOLD)
			badge.draw_rect(Rect2(cx - 6, cy + 2, 12, 3), UI.GOLD_D)
			badge.draw_rect(Rect2(cx - 1, cy - 1, 2, 4), UI.INK)
		elif best > 0:
			var sx := CARD.x - 16.0
			var sy := 6.0
			var star := PackedVector2Array([Vector2(sx + 5, sy), Vector2(sx + 6.6, sy + 3.4), Vector2(sx + 10, sy + 3.8), Vector2(sx + 7.4, sy + 6.2), Vector2(sx + 8.2, sy + 10), Vector2(sx + 5, sy + 8), Vector2(sx + 1.8, sy + 10), Vector2(sx + 2.6, sy + 6.2), Vector2(sx, sy + 3.8), Vector2(sx + 3.4, sy + 3.4)])
			var outline := star.duplicate()
			outline.append(star[0])
			badge.draw_colored_polygon(star, UI.GOLD)
			badge.draw_polyline(outline, UI.INK, 1.0))
	# level number tag
	if not locked:
		var tag := Control.new()
		tag.position = Vector2(4, 4)
		tag.size = Vector2(28, 11)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.draw.connect(func():
			tag.draw_rect(Rect2(0, 0, 28, 11), Color(0.04, 0.04, 0.14, 0.82))
			tag.draw_rect(Rect2(0, 10, 28, 1), UI.GOLD))
		face.add_child(tag)
		var num := UI.label(Game.level_label(i), 8, UI.GOLD, false)
		num.position = Vector2(2, 2)
		tag.add_child(num)
	# name (2 lines) + best score
	var words: PackedStringArray = str(data["name"]).split(" ")
	var dim_c := Color(0.5, 0.5, 0.58) if locked else Color(1.0, 0.92, 0.55)
	var l1 := UI.label(words[0] if not locked else "????", 8, dim_c, false)
	l1.position = Vector2(4, 33)
	l1.clip_text = true
	l1.custom_minimum_size = Vector2(62, 8)
	l1.size = Vector2(62, 8)
	face.add_child(l1)
	if words.size() > 1 and not locked:
		var l2 := UI.label(words[1], 8, dim_c, false)
		l2.position = Vector2(4, 43)
		l2.clip_text = true
		l2.size = Vector2(62, 8)
		face.add_child(l2)
	if best > 0 and not locked:
		var bl := UI.label(str(best), 8, UI.MINT, false)
		bl.position = Vector2(4, 54)
		bl.clip_text = true
		bl.size = Vector2(62, 8)
		face.add_child(bl)
	# focus animation: lift + pulsing frame
	b.focus_entered.connect(func():
		Audio.play("click")
		_show_info(i)
		if st["tw"] and st["tw"].is_valid():
			st["tw"].kill()
		var tw := face.create_tween().set_parallel(true)
		tw.tween_property(face, "position:y", -3.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var pulse := face.create_tween().set_loops()
		pulse.tween_method(func(v: float):
			st["pulse"] = v
			face.queue_redraw(), 0.0, 1.0, 0.35)
		pulse.tween_method(func(v: float):
			st["pulse"] = v
			face.queue_redraw(), 1.0, 0.0, 0.35)
		st["tw"] = pulse
		b.queue_redraw()
		face.queue_redraw())
	b.focus_exited.connect(func():
		if st["tw"] and st["tw"].is_valid():
			st["tw"].kill()
		st["pulse"] = 0.0
		var tw := face.create_tween()
		tw.tween_property(face, "position:y", 0.0, 0.1)
		face.queue_redraw())
	b.mouse_entered.connect(func(): b.grab_focus())
	b.pressed.connect(func():
		if locked:
			Audio.play("bump")
			var sh := face.create_tween()
			for dx in [-3.0, 3.0, -2.0, 2.0, 0.0]:
				sh.tween_property(face, "position:x", dx, 0.04)
			return
		Audio.play("select")
		Game.new_run(i)
		UI.go("res://scenes/level.tscn"))
	# staggered pop-in
	face.modulate.a = 0.0
	face.scale = Vector2(0.6, 0.6)
	var row := (i % 10) / 5
	var col := i % 5
	var delay := 0.12 + (col + row * 2) * 0.05
	var tw_in := face.create_tween().set_parallel(true)
	tw_in.tween_property(face, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw_in.tween_property(face, "modulate:a", 1.0, 0.2).set_delay(delay)
	return b


func _gradient(th: Dictionary) -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, th["sky_top"])
	grad.set_color(1, th["sky_bot"])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 16
	return gt
