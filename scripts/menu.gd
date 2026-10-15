extends Control
## Animated title screen.

const ScrollerScript = preload("res://scripts/scroller.gd")
const ControlsPanel = preload("res://scripts/controls_panel.gd")
const ShopScript = preload("res://scripts/shop.gd")
const Cosmetics = preload("res://scripts/cosmetics.gd")

const LOGO_SHINE := """
shader_type canvas_item;
uniform float t = -0.4;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = UV.x + UV.y * 0.35 - t;
	float band = step(abs(d), 0.045) * 0.55 + step(abs(d + 0.09), 0.02) * 0.3;
	c.rgb += band * c.a;
	COLOR = c;
}
"""

var runner: AnimatedSprite2D
var chaser: AnimatedSprite2D
var logo: TextureRect
var buttons_box: VBoxContainer
var menu_card: Control
var panel_root: Control
var help_btn: Button
var shop_btn: Button
var wallet_row: Control
var wallet_l: Label
var _panel_back: Callable
var coins: Array = []
var _t := 0.0
var _run_x := -30.0
var _logo_drop := -110.0
var _shine_mat: ShaderMaterial


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.play_music("menu")
	var th: Dictionary = Game.LevelsData.THEMES["grass"]
	add_child(Game.make_sky(th["sky_top"], th["sky_bot"]))
	_build_sun()
	_add_clouds()
	_scroller("res://assets/bg/bg_grass_far.png", 0.5, 200.0, 6.0)
	_scroller("res://assets/bg/bg_grass_near.png", 0.5, 204.0, 14.0)
	_build_ground()
	_build_coins()
	_build_runners()
	_build_card_and_buttons()
	_build_logo()
	_build_footer()
	_build_help_button()
	_build_shop_button()
	add_child(UI.vignette(0.45))
	# floating pollen / sparkles in front of everything
	var fx := UI.particles(Vector2(200, 8), Color(1, 1, 0.75, 0.9), 26, 5.0, Vector2(0, -14), Vector2(3, 0), 1.5)
	fx.position = Vector2(200, 200)
	add_child(fx)


func _scroller(path: String, f: float, bottom: float, speed: float) -> void:
	var s = ScrollerScript.new()
	add_child(s)
	s.setup(Game.tex(path), f, bottom, speed)


func _build_sun() -> void:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.set_color(0, Color(1.0, 0.98, 0.78, 1.0))
	g.set_color(1, Color(1.0, 0.95, 0.6, 0.0))
	g.add_point(0.32, Color(1.0, 0.93, 0.55, 0.9))
	g.add_point(0.50, Color(1.0, 0.92, 0.55, 0.35))
	g.add_point(0.70, Color(1.0, 0.92, 0.6, 0.15))
	g.add_point(0.88, Color(1.0, 0.95, 0.7, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	var sun := TextureRect.new()
	sun.texture = gt
	sun.position = Vector2(300, -26)
	sun.size = Vector2(128, 128)
	sun.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sun.stretch_mode = TextureRect.STRETCH_SCALE
	sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sun)
	var tw := sun.create_tween().set_loops()
	tw.tween_property(sun, "modulate:a", 0.75, 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sun, "modulate:a", 1.0, 1.8).set_trans(Tween.TRANS_SINE)


func _add_clouds() -> void:
	for i in 4:
		var s = ScrollerScript.new()
		add_child(s)
		var t := Game.tex("res://assets/sprites/cloud_l.png" if i % 2 == 0 else "res://assets/sprites/cloud_s.png")
		s.setup(t, 1.0, 40.0 + i * 22.0, 4.0 + i * 3.0)
		for sp in s.sprites:
			sp.position.y = 6.0 + i * 20.0
			sp.modulate = Color(1, 1, 1, 0.85)


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


func _build_coins() -> void:
	var frames := Game.make_frames(Game.tex("res://assets/sprites/coin.png"), 16, 16, {
		"spin": {"frames": [0, 1, 2, 3], "fps": 8, "loop": true}})
	for x in [26, 56, 86, 296, 326, 356]:
		var c := AnimatedSprite2D.new()
		c.sprite_frames = frames
		c.offset = Vector2(0, -8)
		c.position = Vector2(x, 180)
		c.play("spin")
		c.frame = randi() % 4
		add_child(c)
		coins.append(c)


func _build_runners() -> void:
	runner = AnimatedSprite2D.new()
	runner.sprite_frames = Cosmetics.small_frames(Game.loadout)
	runner.speed_scale = 1.2
	runner.offset = Vector2(0, -Cosmetics.frame_height(0) * 0.5)
	runner.position = Vector2(-30, 192)
	runner.play("run")
	add_child(runner)
	chaser = AnimatedSprite2D.new()
	chaser.sprite_frames = Game.make_frames(Game.tex("res://assets/sprites/goomba.png"), 16, 16, {
		"walk": {"frames": [0, 1], "fps": 8, "loop": true}})
	chaser.offset = Vector2(0, -8)
	chaser.position = Vector2(-70, 192)
	chaser.play("walk")
	add_child(chaser)


func _build_logo() -> void:
	logo = TextureRect.new()
	logo.texture = Game.tex("res://assets/ui/logo.png")
	logo.position = Vector2(52, 6)
	var sh := Shader.new()
	sh.code = LOGO_SHINE
	_shine_mat = ShaderMaterial.new()
	_shine_mat.shader = sh
	logo.material = _shine_mat
	add_child(logo)
	# drop-in bounce, then a periodic light sweep across the letters
	var drop := create_tween()
	drop.tween_property(self, "_logo_drop", 0.0, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var sweep := create_tween().set_loops()
	sweep.tween_interval(2.2)
	sweep.tween_method(func(v: float): _shine_mat.set_shader_parameter("t", v), -0.3, 1.5, 0.7)


func _build_card_and_buttons() -> void:
	buttons_box = VBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 2)
	var first := UI.button("START GAME", func(): UI.go("res://scenes/level_select.tscn"), 124)
	buttons_box.add_child(first)
	buttons_box.add_child(UI.button("OPTIONS", _open_options, 124))
	if not OS.has_feature("web"):
		buttons_box.add_child(UI.button("QUIT", func(): get_tree().quit(), 124))
	var n := buttons_box.get_child_count()
	var h := n * 17.0 + (n - 1) * 2.0
	# centre the card between the logo (bottom ~84) and the ground (192)
	# soft translucent card behind the buttons
	menu_card = Control.new()
	menu_card.position = Vector2(200 - 70, roundf(138.0 - (h + 12.0) * 0.5))
	menu_card.size = Vector2(140, h + 12)
	menu_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_card.draw.connect(func():
		var s := menu_card.size
		menu_card.draw_rect(Rect2(2, 3, s.x, s.y), Color(0, 0, 0, 0.25))
		menu_card.draw_rect(Rect2(0, 0, s.x, s.y), Color(0.04, 0.06, 0.22, 0.62))
		menu_card.draw_rect(Rect2(0, 0, s.x, s.y), Color(1.0, 0.82, 0.2, 0.9), false, 2.0)
		menu_card.draw_rect(Rect2(3, 3, s.x - 6, 1), Color(1, 1, 1, 0.15)))
	add_child(menu_card)
	buttons_box.position = Vector2(8, 5)
	menu_card.add_child(buttons_box)
	# staggered entrance
	UI.fade_in(menu_card, 0.5, 0.3)
	var i := 0
	for b in buttons_box.get_children():
		UI.pop_in(b, 0.7 + i * 0.07, 0.25)
		i += 1
	first.call_deferred("grab_focus")


func _build_help_button() -> void:
	# small always-visible "?" in the top-right corner (also opens with the H or F1 key)
	help_btn = UI.compact_button("?", func(): _open_help(), 22)
	help_btn.position = Vector2(400 - 22 - 8, 8)
	help_btn.tooltip_text = "HOW TO PLAY (H)"
	add_child(help_btn)
	UI.pop_in(help_btn, 0.9, 0.25)
	var first: Control = buttons_box.get_child(0)
	first.focus_neighbor_top = first.get_path_to(help_btn)
	help_btn.focus_neighbor_bottom = help_btn.get_path_to(first)


## Basket button on the left side of the menu card + the coin balance under it.
func _build_shop_button() -> void:
	var bx := menu_card.position.x - 52.0
	var by := menu_card.position.y + 8.0
	shop_btn = Button.new()
	shop_btn.custom_minimum_size = Vector2(40, 36)
	shop_btn.size = Vector2(40, 36)
	shop_btn.position = Vector2(bx, by)
	shop_btn.tooltip_text = "SHOP (B)"
	UI.style_button(shop_btn)
	shop_btn.focus_entered.connect(func():
		Audio.play("click")
		_wiggle_shop())
	shop_btn.mouse_entered.connect(func(): shop_btn.grab_focus())
	shop_btn.pressed.connect(func():
		Audio.play("select")
		_open_shop())
	shop_btn.draw.connect(func():
		var tex := Cosmetics.basket_icon()
		var lit := shop_btn.has_focus() or shop_btn.is_hovered()
		var y := 6.0 if not lit else 5.0
		shop_btn.draw_texture(tex, Vector2(roundf((shop_btn.size.x - 20.0) * 0.5), y)))
	add_child(shop_btn)
	var lab := UI.label("SHOP", 8, UI.GOLD)
	lab.size = Vector2(40, 10)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.position = Vector2(0, 21)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_btn.add_child(lab)
	# coin balance under the button
	wallet_row = Control.new()
	wallet_row.position = Vector2(bx - 6, by + 41)
	wallet_row.size = Vector2(52, 10)
	wallet_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = Cosmetics.coin_icon()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_row.add_child(ic)
	wallet_l = UI.label("", 8, Color.WHITE)
	wallet_l.position = Vector2(10, 0)
	wallet_row.add_child(wallet_l)
	add_child(wallet_row)
	_refresh_wallet()
	UI.pop_in(shop_btn, 1.0, 0.25)
	var first: Control = buttons_box.get_child(0)
	first.focus_neighbor_left = first.get_path_to(shop_btn)
	shop_btn.focus_neighbor_right = shop_btn.get_path_to(first)
	shop_btn.focus_neighbor_left = shop_btn.get_path_to(shop_btn)
	shop_btn.focus_neighbor_top = shop_btn.get_path_to(help_btn)
	shop_btn.focus_neighbor_bottom = shop_btn.get_path_to(shop_btn)
	for i in range(1, buttons_box.get_child_count()):
		var bb: Control = buttons_box.get_child(i)
		bb.focus_neighbor_left = bb.get_path_to(shop_btn)


func _refresh_wallet() -> void:
	wallet_l.text = str(Game.wallet)
	# centre the "coin + number" pair under the button
	var w := 10.0 + wallet_l.text.length() * 8.0
	wallet_row.position.x = shop_btn.position.x + roundf((40.0 - w) * 0.5)


func _wiggle_shop() -> void:
	var tw := shop_btn.create_tween()
	tw.tween_property(shop_btn, "position:y", shop_btn.position.y - 2.0, 0.06)
	tw.tween_property(shop_btn, "position:y", shop_btn.position.y, 0.08)


func _refresh_runner() -> void:
	runner.sprite_frames = Cosmetics.small_frames(Game.loadout)
	runner.play("run")


func _open_shop() -> void:
	if panel_root:
		panel_root.queue_free()
		panel_root = null
	_panel_back = _close_shop
	menu_card.visible = false
	help_btn.visible = false
	shop_btn.visible = false
	wallet_row.visible = false
	var sh = ShopScript.new()
	sh.z_index = 10
	sh.close_requested.connect(_close_shop)
	panel_root = sh
	add_child(sh)


func _close_shop() -> void:
	_close_panel()
	_refresh_wallet()
	_refresh_runner()
	if is_instance_valid(shop_btn):
		shop_btn.grab_focus()


func _build_footer() -> void:
	var l := UI.label("(C) 2026 PIXEL BROS", 8, Color(1, 1, 1, 0.9))
	l.position = Vector2(8, 211)
	add_child(l)
	var hi := 0
	for k in Game.best_scores:
		hi = maxi(hi, int(Game.best_scores[k]))
	var r := UI.label("HI " + UI.score_text(hi), 8, UI.GOLD)
	r.position = Vector2(400 - 8 * 9 - 8, 211)
	add_child(r)


func _process(delta: float) -> void:
	_t += delta
	logo.position.y = 6.0 + roundf(sin(_t * 2.2) * 2.0) + roundf(_logo_drop)
	_run_x += 70.0 * delta
	if _run_x > 460.0:
		_run_x = -30.0
		for c in coins:
			c.visible = true
	runner.position.x = roundf(_run_x)
	chaser.position.x = roundf(_run_x - 44.0)
	for c in coins:
		c.position.y = 180.0 + roundf(sin(_t * 4.0 + c.position.x * 0.1) * 1.5)
		if c.visible and _run_x >= c.position.x - 4.0 and _run_x <= c.position.x + 40.0:
			c.visible = false
			UI.burst(self, Vector2(c.position.x, 176), 10, 70.0, [UI.GOLD, Color(1, 0.95, 0.6), Color.WHITE])


# ------------------------------------------------------------------ panels
func _close_panel() -> void:
	if panel_root:
		panel_root.queue_free()
		panel_root = null
	menu_card.visible = true
	help_btn.visible = true
	if shop_btn:
		shop_btn.visible = true
		wallet_row.visible = true
	UI.fade_in(menu_card, 0.0, 0.15)
	for b in buttons_box.get_children():
		if b is Button and not b.disabled:
			b.grab_focus()
			break


func _open_panel(title: String, content: Control, back_label: String = "BACK", back_cb: Callable = Callable(), gap: int = 6) -> void:
	if panel_root:
		panel_root.visible = false
		panel_root.queue_free()
		panel_root = null
	_panel_back = back_cb if back_cb.is_valid() else _close_panel
	menu_card.visible = false
	help_btn.visible = false
	if shop_btn:
		shop_btn.visible = false
		wallet_row.visible = false
	panel_root = Control.new()
	panel_root.size = Vector2(400, 224)
	panel_root.z_index = 10
	add_child(panel_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.12, 0.55)
	dim.size = Vector2(400, 224)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(dim)
	UI.fade_in(dim, 0.0, 0.2)
	var p := UI.panel(Vector2(300, 0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", gap)
	p.add_child(vb)
	var tl := UI.label(title, 16, Color(1.0, 0.85, 0.25))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	var sep := ColorRect.new()
	sep.color = Color(1.0, 0.82, 0.2, 0.35)
	sep.custom_minimum_size = Vector2(0, 1)
	vb.add_child(sep)
	vb.add_child(content)
	var back := UI.button(back_label, _panel_back, 120)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(back)
	vb.add_child(hb)
	var cc := CenterContainer.new()
	cc.size = Vector2(400, 224)
	cc.position = Vector2(0, 0)
	cc.add_child(p)
	panel_root.add_child(cc)
	UI.pop_in(p, 0.0, 0.3)
	back.call_deferred("grab_focus")


func _help_row(desc: String, keys: Array) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	var d := UI.label(desc, 8)
	d.custom_minimum_size = Vector2(88, 0)
	hb.add_child(d)
	var kb := HBoxContainer.new()
	kb.add_theme_constant_override("separation", 3)
	for k in keys:
		kb.add_child(UI.keycap(k))
	hb.add_child(kb)
	return hb


## Opens HOW TO PLAY (touch buttons first; keyboard / gamepad are fixed and always work).
func _open_help(back_cb: Callable = Callable()) -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	vb.add_child(_help_row("MOVE", ["LEFT", "RIGHT"]))
	vb.add_child(_help_row("JUMP", ["JUMP"]))
	vb.add_child(_help_row("RUN", ["RUN"]))
	vb.add_child(_help_row("FIREBALL", ["FIRE"]))
	vb.add_child(_help_row("PAUSE", ["II"]))
	vb.add_child(_help_row("ENTER PIPE", ["DOWN"]))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	vb.add_child(gap)
	for line in ["HOLD JUMP = JUMP HIGHER", "MOVE / RESIZE BUTTONS:", "OPTIONS > CONTROLS", "KEYBOARD + GAMEPAD WORK TOO"]:
		var l := UI.label(line, 8, UI.MINT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
	_open_panel("HOW TO PLAY", vb, "BACK", back_cb)


func _open_controls() -> void:
	var cp := ControlsPanel.new()
	_open_panel("CONTROLS", cp, "BACK", _open_options, 3)
	cp.call_deferred("focus_first")


func _open_options() -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.add_child(UI.slider("MUSIC", func(): return Game.music_volume, func(v: float):
		Game.music_volume = v
		Audio.update_volumes()
		Game.save_game(), 276))
	vb.add_child(UI.slider("SOUND", func(): return Game.sfx_volume, func(v: float):
		Game.sfx_volume = v
		Game.save_game(), 276))
	if not OS.has_feature("mobile"):
		vb.add_child(UI.toggle("FULLSCREEN", func(): return Game.fullscreen, func(on: bool):
			Game.fullscreen = on
			Game.apply_settings()
			Game.save_game(), 276))
	vb.add_child(UI.button("TOUCH CONTROLS", _open_controls, 276))
	vb.add_child(UI.button("HOW TO PLAY", func(): _open_help(_open_options), 276))
	var armed := {"v": false}
	var rb := UI.button("RESET PROGRESS", func(): pass, 276)
	rb.pressed.connect(func():
		if not armed["v"]:
			armed["v"] = true
			rb.text = "SURE? PRESS AGAIN"
			rb.add_theme_color_override("font_color", Color(1.0, 0.7, 0.65))
			return
		Game.unlocked = 1
		Game.best_scores = {}
		Game.save_game()
		armed["v"] = false
		rb.text = "PROGRESS RESET!"
		rb.add_theme_color_override("font_color", UI.MINT))
	rb.focus_exited.connect(func():
		if armed["v"]:
			armed["v"] = false
			rb.text = "RESET PROGRESS"
			rb.remove_theme_color_override("font_color"))
	vb.add_child(rb)
	_open_panel("OPTIONS", vb)


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and panel_root:
		_panel_back.call()
		get_viewport().set_input_as_handled()
		return
	var ke := event as InputEventKey
	if (ke != null and ke.pressed and not ke.echo and panel_root == null
			and (ke.physical_keycode == KEY_H or ke.physical_keycode == KEY_F1)):
		_open_help()
		get_viewport().set_input_as_handled()
	elif ke != null and ke.pressed and not ke.echo and panel_root == null and ke.physical_keycode == KEY_B:
		_open_shop()
		get_viewport().set_input_as_handled()
