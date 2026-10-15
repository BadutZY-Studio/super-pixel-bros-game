extends Node
## UI helpers: pixel font, styled buttons / panels / sliders, particles and
## scene transitions (autoload "UI").

const GOLD := Color(1.0, 0.82, 0.2)
const GOLD_D := Color(0.55, 0.30, 0.02)
const RED := Color(0.93, 0.27, 0.22)
const RED_D := Color(0.50, 0.10, 0.12)
const NAVY := Color(0.09, 0.10, 0.28)
const NAVY_D := Color(0.04, 0.05, 0.16)
const BLUE := Color(0.20, 0.28, 0.70)
const BLUE_L := Color(0.40, 0.55, 1.0)
const MINT := Color(0.50, 1.0, 0.70)
const INK := Color(0.07, 0.05, 0.12)
const SCREEN := Vector2(400, 224)

const WIPE_SHADER := """
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 grid = vec2(25.0, 14.0);
void fragment() {
	vec2 g = UV * grid;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float d = (cell.x / grid.x + cell.y / grid.y) * 0.5;
	float s = clamp((progress - d * 0.55) / 0.45, 0.0, 1.0);
	float m = max(abs(f.x - 0.5), abs(f.y - 0.5)) * 2.0;
	float a = step(m, s * 1.001);
	if (s <= 0.0) { a = 0.0; }
	COLOR = vec4(0.03, 0.02, 0.09, a);
}
"""

var font: Font = null
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _wipe_mat: ShaderMaterial
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists("res://assets/fonts/PressStart2P.ttf"):
		font = load("res://assets/fonts/PressStart2P.ttf")
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.WHITE
	_fade_rect.size = SCREEN
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = WIPE_SHADER
	_wipe_mat = ShaderMaterial.new()
	_wipe_mat.shader = sh
	_wipe_mat.set_shader_parameter("progress", 0.0)
	_fade_rect.material = _wipe_mat
	_fade_layer.add_child(_fade_rect)


func _fnt() -> Font:
	return font if font else ThemeDB.fallback_font


# ------------------------------------------------------------------ transitions
func _set_wipe(v: float) -> void:
	_wipe_mat.set_shader_parameter("progress", v)


func go(path: String, dur: float = 0.4) -> void:
	if _busy:
		return
	_busy = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_method(_set_wipe, 0.0, 1.0, dur)
	await t.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_method(_set_wipe, 1.0, 0.0, dur)
	await t2.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


# ------------------------------------------------------------------ labels
func label(text: String, size: int = 8, color: Color = Color.WHITE, outline: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_constant_override("outline_size", 2)
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("shadow_offset_y", 1)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	return l


## Label with a fixed 400px width, centred horizontally (handy for slide-in titles).
func wide_label(text: String, size: int, color: Color, y: float) -> Label:
	var l := label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(SCREEN.x, size + 4)
	# Press Start 2P keeps a blank pixel column on the right of every glyph, so centred
	# text looks shifted left; nudge by half of that column (whole pixels only).
	l.position = Vector2(floorf(size / 16.0), floorf(y))
	return l


func score_text(v: int, digits: int = 6) -> String:
	return str(v).pad_zeros(digits)


# ------------------------------------------------------------------ boxes
func _box(bg: Color, border: Color, bw: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 3
	s.content_margin_bottom = 4
	return s


func _btn_box(bg: Color, border: Color, top_bw: int = 2, bottom_bw: int = 4) -> StyleBoxFlat:
	var s := _box(bg, border, 2)
	s.border_width_top = top_bw
	s.border_width_bottom = bottom_bw
	s.content_margin_left = 16
	s.content_margin_right = 12
	s.content_margin_top = 8 - bottom_bw / 2 + (top_bw - 2)
	s.content_margin_bottom = 2 + bottom_bw / 2
	return s


func style_button(b: Button) -> void:
	if font:
		b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 8)
	var normal := _btn_box(BLUE, INK)
	var hover := _btn_box(GOLD, GOLD_D)
	var pressed := _btn_box(Color(0.95, 0.55, 0.12), GOLD_D, 4, 2)
	var disabled := _btn_box(Color(0.18, 0.19, 0.26), Color(0.08, 0.08, 0.12))
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color(0.2, 0.1, 0.0))
	b.add_theme_color_override("font_focus_color", Color(0.2, 0.1, 0.0))
	b.add_theme_color_override("font_pressed_color", Color(0.2, 0.1, 0.0))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.52))
	b.add_theme_constant_override("outline_size", 0)
	b.focus_mode = Control.FOCUS_ALL
	b.draw.connect(func():
		var w := b.size.x
		var h := b.size.y
		if b.disabled:
			return
		var lit := b.has_focus() or b.is_hovered()
		var pr := b.button_pressed or (lit and Input.is_action_pressed("ui_accept"))
		var top := Color(1, 1, 1, 0.45) if lit else Color(1, 1, 1, 0.20)
		var bot := Color(0.0, 0.0, 0.0, 0.28)
		if pr:
			top = Color(0, 0, 0, 0.15)
			bot = Color(1, 1, 1, 0.0)
		b.draw_rect(Rect2(2, 2, w - 4, 1), top)
		b.draw_rect(Rect2(2, h - 6 if not pr else h - 4, w - 4, 2), bot)
		# little corner studs
		var stud := Color(1, 1, 1, 0.35) if lit else Color(1, 1, 1, 0.18)
		b.draw_rect(Rect2(4, 4, 1, 1), stud)
		b.draw_rect(Rect2(w - 5, 4, 1, 1), stud))


## Gold arrow + light sweep when a button gets focus.
func _focus_fx(b: Button) -> void:
	var arrow := label(">", 8, INK, false)
	arrow.position = Vector2(4, 5)
	arrow.visible = false
	b.add_child(arrow)
	var shine := ColorRect.new()
	shine.color = Color(1, 1, 1, 0.38)
	shine.size = Vector2(6, 60)
	shine.position = Vector2(-14, -8)
	shine.rotation = 0.35
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.visible = false
	b.add_child(shine)
	b.clip_contents = true
	var st := {"bob": null, "sweep": null}
	b.focus_entered.connect(func():
		arrow.visible = true
		if st["bob"] and st["bob"].is_valid():
			st["bob"].kill()
		var tw := arrow.create_tween().set_loops()
		tw.tween_property(arrow, "position:x", 7.0, 0.22)
		tw.tween_property(arrow, "position:x", 4.0, 0.22)
		st["bob"] = tw
		if st["sweep"] and st["sweep"].is_valid():
			st["sweep"].kill()
		shine.visible = true
		shine.position.x = -14
		var t2 := shine.create_tween()
		t2.tween_property(shine, "position:x", b.size.x + 14, 0.4)
		t2.tween_callback(func(): shine.visible = false)
		st["sweep"] = t2
		b.queue_redraw())
	b.focus_exited.connect(func():
		arrow.visible = false
		if st["bob"] and st["bob"].is_valid():
			st["bob"].kill()
		b.queue_redraw())
	b.mouse_exited.connect(func(): b.queue_redraw())


func button(text: String, callback: Callable, width: float = 120.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 17)
	style_button(b)
	_focus_fx(b)
	b.pressed.connect(func():
		Audio.play("select")
		callback.call())
	b.mouse_entered.connect(func():
		if not b.disabled:
			b.grab_focus())
	b.focus_entered.connect(func(): Audio.play("click"))
	return b


## Wires explicit focus neighbours for a grid of controls (an Array of rows, each an Array of controls).
## Left / right / up / down move exactly ONE cell and stop at the edges, instead of relying on Godot's
## geometric guess (which can jump to a control in a different row when widths overlap).
## Rows may have different lengths: a vertical move lands on the same column, or the row's last cell.
## Call it once every control is inside the scene tree.
func wire_focus_grid(rows: Array) -> void:
	for r in rows.size():
		var row: Array = rows[r]
		var up_row: Array = rows[maxi(r - 1, 0)]
		var down_row: Array = rows[mini(r + 1, rows.size() - 1)]
		for c in row.size():
			var ctl: Control = row[c]
			ctl.focus_neighbor_left = ctl.get_path_to(row[maxi(c - 1, 0)])
			ctl.focus_neighbor_right = ctl.get_path_to(row[mini(c + 1, row.size() - 1)])
			ctl.focus_neighbor_top = ctl.get_path_to(up_row[mini(c, up_row.size() - 1)])
			ctl.focus_neighbor_bottom = ctl.get_path_to(down_row[mini(c, down_row.size() - 1)])


## Narrow button with little padding and no focus arrow (key-bind slots, small icons).
func compact_button(text: String, callback: Callable, width: float) -> Button:
	var b := button(text, callback, width)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := b.get_theme_stylebox(st).duplicate() as StyleBoxFlat
		sb.content_margin_left = 2
		sb.content_margin_right = 2
		b.add_theme_stylebox_override(st, sb)
	for ch in b.get_children():
		if ch is Label:
			(ch as Label).text = ""
	return b


## Volume style row: label + 10 segments. Left/Right changes it, click on a segment sets it.
## get_v returns 0..1, set_v receives a 0..1 value snapped to 0.1.
func slider(text: String, get_v: Callable, set_v: Callable, width: float = 260.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(width, 17)
	b.text = ""
	style_button(b)
	_focus_fx(b)
	var st := {"skip": false, "bx": 0.0, "sw": 0.0, "gap": 1.0}
	b.draw.connect(func():
		var v: float = get_v.call()
		var lit := b.has_focus() or b.is_hovered()
		var f := _fnt()
		var base_y := 12.0 if not b.button_pressed else 13.0
		var col := Color(0.2, 0.1, 0.0) if lit else Color.WHITE
		if not lit:
			b.draw_string_outline(f, Vector2(16, base_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, INK)
		b.draw_string(f, Vector2(16, base_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		var pct := "%d%%" % int(round(v * 100.0))
		var pw := 4.0 * 8.0
		b.draw_string(f, Vector2(width - pw - 8.0, base_y), pct.lpad(4), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		var avail := width - 64.0 - pw - 12.0
		var gap := 1.0
		var sw: float = clampf(floorf((avail - 9.0 * gap) / 10.0), 3.0, 9.0)
		var total := sw * 10.0 + gap * 9.0
		var x0 := 64.0 + (avail - total) * 0.5
		st["bx"] = x0
		st["sw"] = sw
		st["gap"] = gap
		var filled := int(round(v * 10.0))
		for i in 10:
			var on := i < filled
			var c: Color
			if lit:
				c = Color(0.35, 0.18, 0.0) if on else Color(0.75, 0.58, 0.12)
			else:
				c = MINT.lerp(Color(1.0, 0.95, 0.4), float(i) / 9.0) if on else Color(0.10, 0.12, 0.32)
			var x := x0 + i * (sw + gap)
			b.draw_rect(Rect2(x, 5, sw, 7), c)
			if on and not lit:
				b.draw_rect(Rect2(x, 5, sw, 2), Color(1, 1, 1, 0.35)))
	var change := func(delta: float):
		var v: float = get_v.call()
		v = clampf(snappedf(v + delta, 0.1), 0.0, 1.0)
		set_v.call(v)
		Audio.play("click")
		b.queue_redraw()
	b.gui_input.connect(func(ev: InputEvent):
		if ev.is_action_pressed("ui_left") or ev.is_action_pressed("left"):
			change.call(-0.1)
			b.accept_event()
		elif ev.is_action_pressed("ui_right") or ev.is_action_pressed("right"):
			change.call(0.1)
			b.accept_event()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var x: float = ev.position.x
			var x0: float = st["bx"]
			var span: float = st["sw"] * 10.0 + st["gap"] * 9.0
			if x >= x0 - 2.0 and x <= x0 + span + 2.0:
				var idx := int(clampf(floorf((x - x0) / (st["sw"] + st["gap"])), 0.0, 9.0)) + 1
				var cur := int(round(float(get_v.call()) * 10.0))
				set_v.call(0.0 if (idx == 1 and cur == 1) else idx / 10.0)
				st["skip"] = true
				Audio.play("click")
				b.queue_redraw())
	b.pressed.connect(func():
		if st["skip"]:
			st["skip"] = false
			return
		var v: float = get_v.call()
		v = snappedf(v + 0.1, 0.1)
		if v > 1.0001:
			v = 0.0
		set_v.call(v)
		Audio.play("select")
		b.queue_redraw())
	b.mouse_entered.connect(func(): b.grab_focus())
	b.focus_entered.connect(func(): Audio.play("click"))
	return b


## ON/OFF row with a small switch.
func toggle(text: String, get_b: Callable, set_b: Callable, width: float = 260.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(width, 17)
	b.text = ""
	style_button(b)
	_focus_fx(b)
	b.draw.connect(func():
		var on: bool = get_b.call()
		var lit := b.has_focus() or b.is_hovered()
		var f := _fnt()
		var by := 12.0 if not b.button_pressed else 13.0
		var col := Color(0.2, 0.1, 0.0) if lit else Color.WHITE
		if not lit:
			b.draw_string_outline(f, Vector2(16, by), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, INK)
		b.draw_string(f, Vector2(16, by), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		var sx := width - 12.0 - 22.0
		var track := MINT if on else Color(0.10, 0.12, 0.32)
		if lit:
			track = Color(0.35, 0.18, 0.0) if on else Color(0.75, 0.58, 0.12)
		b.draw_rect(Rect2(sx, 4, 22, 9), track)
		var kx := sx + (13.0 if on else 1.0)
		b.draw_rect(Rect2(kx, 5, 8, 7), Color(1, 1, 1))
		b.draw_rect(Rect2(kx, 10, 8, 2), Color(0.75, 0.78, 0.9))
		var t := "ON" if on else "OFF"
		var tw := t.length() * 8.0
		b.draw_string(f, Vector2(sx - tw - 6.0, by), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			(Color(0.1, 0.4, 0.15) if lit else MINT) if on else (Color(0.5, 0.3, 0.05) if lit else Color(0.6, 0.62, 0.8))))
	b.gui_input.connect(func(ev: InputEvent):
		if ev.is_action_pressed("ui_left") or ev.is_action_pressed("left") or ev.is_action_pressed("ui_right") or ev.is_action_pressed("right"):
			set_b.call(not bool(get_b.call()))
			Audio.play("select")
			b.queue_redraw()
			b.accept_event())
	b.pressed.connect(func():
		set_b.call(not bool(get_b.call()))
		Audio.play("select")
		b.queue_redraw())
	b.mouse_entered.connect(func(): b.grab_focus())
	b.focus_entered.connect(func(): Audio.play("click"))
	return b


# ------------------------------------------------------------------ panels
func panel(min_size: Vector2 = Vector2.ZERO, accent: Color = GOLD) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _box(Color(0.05, 0.06, 0.20, 0.96), accent, 2)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 9
	s.content_margin_bottom = 11
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 2
	s.shadow_offset = Vector2(2, 3)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = min_size
	p.draw.connect(func():
		var w := p.size.x
		var h := p.size.y
		# inner frame line + top sheen
		p.draw_rect(Rect2(4, 4, w - 8, h - 8), Color(1, 1, 1, 0.07), false, 1.0)
		p.draw_rect(Rect2(2, 2, w - 4, 3), Color(1, 1, 1, 0.10))
		p.draw_rect(Rect2(2, h - 5, w - 4, 3), Color(0, 0, 0, 0.25))
		# corner studs
		for c in [Vector2(2, 2), Vector2(w - 6, 2), Vector2(2, h - 6), Vector2(w - 6, h - 6)]:
			p.draw_rect(Rect2(c.x, c.y, 4, 4), accent)
			p.draw_rect(Rect2(c.x + 1, c.y + 1, 2, 2), Color(1, 1, 1, 0.65)))
	return p


## Red ribbon banner for titles.
func ribbon(text: String, size: int = 16, color: Color = RED) -> PanelContainer:
	var p := PanelContainer.new()
	var dark := color.darkened(0.45)
	var s := _box(color, INK, 2)
	s.border_width_bottom = 4
	s.content_margin_left = 12 + size / 8.0
	s.content_margin_right = 12
	s.content_margin_top = 5
	s.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	var l := label(text, size, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.draw.connect(func():
		var w := p.size.x
		var h := p.size.y
		p.draw_rect(Rect2(2, 2, w - 4, 2), Color(1, 1, 1, 0.35))
		# folded tails with a notch
		var lt := PackedVector2Array([Vector2(-12, 6), Vector2(3, 6), Vector2(3, h + 2), Vector2(-12, h + 2), Vector2(-7, (h + 8) * 0.5)])
		var rt := PackedVector2Array([Vector2(w + 12, 6), Vector2(w - 3, 6), Vector2(w - 3, h + 2), Vector2(w + 12, h + 2), Vector2(w + 7, (h + 8) * 0.5)])
		p.draw_colored_polygon(lt, dark)
		p.draw_colored_polygon(rt, dark)
		p.draw_rect(Rect2(-1, h - 1, 4, 3), INK)
		p.draw_rect(Rect2(w - 3, h - 1, 4, 3), INK))
	return p


## Ribbon that is ALWAYS horizontally centred on the 400px screen. It is wrapped in a
## full-width CenterContainer, so centring happens after layout (measuring the ribbon's
## size before it is in the tree gives a wrong width, which made it lean to the right).
func ribbon_centered(text: String, y: float, size: int = 16, color: Color = RED) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.size = Vector2(SCREEN.x, 30)
	cc.position = Vector2(0, y)
	cc.add_child(ribbon(text, size, color))
	return cc


func keycap(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _box(Color(0.88, 0.90, 1.0), INK, 1)
	s.border_width_bottom = 3
	s.content_margin_left = 5
	s.content_margin_right = 5
	s.content_margin_top = 2
	s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	p.add_child(label(text, 8, Color(0.12, 0.12, 0.3), false))
	return p


func vignette(strength: float = 0.55) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.02, 0.0, 0.08, strength))
	g.add_point(0.55, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 200
	gt.height = 112
	var tr := TextureRect.new()
	tr.texture = gt
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = SCREEN
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


# ------------------------------------------------------------------ animation
func pop_in(c: Control, delay: float = 0.0, dur: float = 0.3) -> void:
	c.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.82, 0.82)
	var t := c.create_tween().set_parallel(true)
	t.tween_property(c, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	t.tween_property(c, "modulate:a", 1.0, dur * 0.6).set_delay(delay)


func fade_in(c: CanvasItem, delay: float = 0.0, dur: float = 0.25) -> void:
	c.modulate.a = 0.0
	var t := c.create_tween()
	t.tween_property(c, "modulate:a", 1.0, dur).set_delay(delay)


func slide_in(c: Control, from: Vector2, delay: float = 0.0, dur: float = 0.4, trans: Tween.TransitionType = Tween.TRANS_BACK) -> void:
	var target := c.position
	c.position = target + from
	c.modulate.a = 0.0
	var t := c.create_tween().set_parallel(true)
	t.tween_property(c, "position", target, dur).set_trans(trans).set_ease(Tween.EASE_OUT).set_delay(delay)
	t.tween_property(c, "modulate:a", 1.0, dur * 0.5).set_delay(delay)


# ------------------------------------------------------------------ particles
func particles(extents: Vector2, color: Color, amount: int, life: float, vel: Vector2, gravity: Vector2 = Vector2.ZERO, px: float = 2.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.direction = Vector2(0, -1) if vel.y < 0.0 else Vector2(1, 0)
	p.spread = 30.0
	p.initial_velocity_min = vel.length() * 0.6
	p.initial_velocity_max = vel.length()
	p.gravity = gravity
	p.scale_amount_min = px
	p.scale_amount_max = px * 1.5
	p.local_coords = false
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 0.0))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	g.add_point(0.25, color)
	g.add_point(0.75, color)
	p.color_ramp = g
	return p


## One-shot burst of confetti / sparks (frees itself).
func burst(parent: Node, pos: Vector2, amount: int = 24, spread_speed: float = 120.0, colors: Array = []) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = spread_speed * 0.5
	p.initial_velocity_max = spread_speed
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.local_coords = false
	var g := Gradient.new()
	var cols: Array = colors if colors.size() >= 2 else [GOLD, RED, MINT, BLUE_L, Color.WHITE]
	g.set_color(0, cols[0])
	g.set_color(1, cols[cols.size() - 1])
	for i in range(1, cols.size() - 1):
		g.add_point(float(i) / float(cols.size() - 1), cols[i])
	p.color_initial_ramp = g
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
