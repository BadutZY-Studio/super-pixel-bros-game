extends Control
## The cosmetic shop screen (opened with the basket button on the title menu).
## Layout (400 x 224): header with wallet, live preview on the left, category tabs + item grid on
## the right, info bar at the bottom. Keyboard, mouse, touch and gamepad all work.
## Buying an item opens a BUY / CANCEL confirmation modal first.

signal close_requested

const Cosmetics = preload("res://scripts/cosmetics.gd")

const COLS := 5
const CELL := Vector2(52, 40)
const GAP := 2
const TAB_GAP := 1
const GRID_POS := Vector2(123, 53)
const TAB_W := 44

var tab := 0
var tab_btns: Array = []
var cells: Array = []
var cell_items: Array = []
var sel: Dictionary = {}
var back_btn: Button

var wallet_l: Label
var name_l: Label
var price_l: Label
var desc_l: Label
var msg_l: Label
var tag_l: Label
var preview_box: Control
var trail_layer: Node2D
var hero: AnimatedSprite2D
var _grid_root: Control
var _last_sig := ""
var _anim_i := 0
var _anim_t := 0.0
var _trail_t := 0.0
var _trail_n := 0
var _msg_tween: Tween

# confirm-purchase modal
const MODAL_SIZE := Vector2(236, 118)
var _modal: Control = null
var _modal_item: Dictionary = {}
var _modal_cell: Control = null
var _modal_unlock := 0      # ticks (ms) before the modal buttons react, stops double taps
var _mute_click := false
var _rng := RandomNumberGenerator.new()
const ANIM_CYCLE := [["idle", 1.5], ["run", 1.6], ["jump", 0.8], ["run", 1.2]]


func _ready() -> void:
	size = Vector2(400, 224)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.12, 0.88)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_build_frame()
	_build_header()
	_build_preview()
	_build_tabs()
	_grid_root = Control.new()
	_grid_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid_root)
	_build_info_bar()
	back_btn = UI.button("BACK", func(): close_requested.emit(), 108)
	back_btn.position = Vector2(8, 158)
	add_child(back_btn)
	_open_tab(0)
	UI.pop_in(self, 0.0, 0.2)
	call_deferred("_focus_first")


func _focus_first() -> void:
	if not cells.is_empty():
		(cells[0] as Control).grab_focus()


# ------------------------------------------------------------------ static layout
func _build_frame() -> void:
	var frame := Control.new()
	frame.position = Vector2(3, 3)
	frame.size = Vector2(394, 218)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(func():
		var s := frame.size
		frame.draw_rect(Rect2(2, 3, s.x, s.y), Color(0, 0, 0, 0.45))
		frame.draw_rect(Rect2(0, 0, s.x, s.y), Color(0.05, 0.06, 0.20, 0.97))
		frame.draw_rect(Rect2(0, 0, s.x, s.y), UI.GOLD, false, 2.0)
		frame.draw_rect(Rect2(4, 4, s.x - 8, s.y - 8), Color(1, 1, 1, 0.07), false, 1.0)
		frame.draw_rect(Rect2(2, 2, s.x - 4, 3), Color(1, 1, 1, 0.10))
		for c in [Vector2(2, 2), Vector2(s.x - 6, 2), Vector2(2, s.y - 6), Vector2(s.x - 6, s.y - 6)]:
			frame.draw_rect(Rect2(c.x, c.y, 4, 4), UI.GOLD)
			frame.draw_rect(Rect2(c.x + 1, c.y + 1, 2, 2), Color(1, 1, 1, 0.65)))
	add_child(frame)


func _build_header() -> void:
	var icon := TextureRect.new()
	icon.texture = Cosmetics.basket_icon()
	icon.position = Vector2(10, 8)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	var title := UI.label("SHOP", 16, Color(1.0, 0.85, 0.25))
	title.position = Vector2(36, 8)
	add_child(title)
	var coin := TextureRect.new()
	coin.texture = Cosmetics.coin_icon()
	coin.size = Vector2(12, 12)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_SCALE
	coin.position = Vector2(284, 10)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coin)
	wallet_l = UI.label("", 16, Color.WHITE)
	wallet_l.size = Vector2(92, 18)
	wallet_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet_l.position = Vector2(298, 8)
	add_child(wallet_l)
	_set_wallet(false)
	var rule := ColorRect.new()
	rule.color = Color(1.0, 0.82, 0.2, 0.35)
	rule.position = Vector2(8, 28)
	rule.size = Vector2(384, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)


func _set_wallet(animate: bool) -> void:
	wallet_l.text = str(Game.wallet)
	if animate:
		wallet_l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
		var tw := wallet_l.create_tween()
		tw.tween_property(wallet_l, "position:y", 5.0, 0.06)
		tw.tween_property(wallet_l, "position:y", 8.0, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func(): wallet_l.add_theme_color_override("font_color", Color.WHITE))


func _build_preview() -> void:
	preview_box = Control.new()
	preview_box.position = Vector2(8, 32)
	preview_box.size = Vector2(108, 122)
	preview_box.clip_contents = true
	preview_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview_box)
	var th: Dictionary = Game.LevelsData.THEMES["grass"]
	var sky := Game.make_sky(th["sky_top"], th["sky_bot"])
	sky.size = preview_box.size
	preview_box.add_child(sky)
	var cloud := Sprite2D.new()
	cloud.texture = Game.tex("res://assets/sprites/cloud_s.png")
	cloud.centered = false
	cloud.position = Vector2(62, 8)
	cloud.modulate = Color(1, 1, 1, 0.9)
	preview_box.add_child(cloud)
	var hill := Sprite2D.new()
	hill.texture = Game.tex("res://assets/sprites/hill_l.png")
	hill.centered = false
	var hs: Vector2 = hill.texture.get_size()
	hill.position = Vector2(-10, 90 - hs.y)
	preview_box.add_child(hill)
	var tiles := Game.tex("res://assets/tiles/tiles_grass.png")
	for k in 2:
		var at := AtlasTexture.new()
		at.atlas = tiles
		at.region = Rect2(0 if k == 0 else 16, 0, 16, 16)
		var tr := TextureRect.new()
		tr.texture = at
		tr.stretch_mode = TextureRect.STRETCH_TILE
		tr.position = Vector2(0, 90 + k * 16)
		tr.size = Vector2(108, 16 if k == 0 else 20)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_box.add_child(tr)
	trail_layer = Node2D.new()
	preview_box.add_child(trail_layer)
	hero = AnimatedSprite2D.new()
	hero.scale = Vector2(3, 3)
	hero.position = Vector2(54, 90)
	hero.offset = Vector2(0, -Cosmetics.frame_height(0) * 0.5)
	preview_box.add_child(hero)
	tag_l = UI.label("", 8, UI.MINT)
	tag_l.size = Vector2(108, 10)
	tag_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_l.position = Vector2(0, 108)
	preview_box.add_child(tag_l)
	var ov := Control.new()
	ov.size = preview_box.size
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.draw.connect(func(): ov.draw_rect(Rect2(0, 0, ov.size.x, ov.size.y), UI.GOLD_D, false, 2.0))
	preview_box.add_child(ov)


func _build_tabs() -> void:
	for i in Cosmetics.SLOTS.size():
		var slot: String = Cosmetics.SLOTS[i]
		var b := Button.new()
		b.text = ""
		b.custom_minimum_size = Vector2(TAB_W, 16)
		b.size = Vector2(TAB_W, 16)
		b.position = Vector2(123 + i * (TAB_W + TAB_GAP), 32)
		b.focus_mode = Control.FOCUS_ALL
		var idx := i
		var label_text: String = Cosmetics.SLOT_NAMES[slot]
		b.draw.connect(func():
			var on: bool = idx == tab
			var col := Color(0.2, 0.1, 0.0) if on else Color.WHITE
			var w := label_text.length() * 8.0
			var pos := Vector2(roundf((b.size.x - w) * 0.5), 12.0)
			if not on:
				b.draw_string_outline(_font(), pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, UI.INK)
			b.draw_string(_font(), pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col))
		b.pressed.connect(func():
			Audio.play("select")
			_open_tab(idx))
		b.focus_entered.connect(func(): Audio.play("click"))
		b.mouse_entered.connect(func(): b.grab_focus())
		add_child(b)
		tab_btns.append(b)
	_restyle_tabs()


func _tab_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.border_width_bottom = 2
	s.content_margin_left = 1
	s.content_margin_right = 1
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	return s


func _restyle_tabs() -> void:
	for i in tab_btns.size():
		var b: Button = tab_btns[i]
		var on: bool = i == tab
		var normal := _tab_box(UI.GOLD if on else UI.BLUE, UI.GOLD_D if on else UI.INK)
		var hover := _tab_box(Color(1.0, 0.92, 0.45) if on else Color(0.30, 0.42, 0.90), UI.GOLD_D if on else Color.WHITE)
		for st in ["normal", "pressed"]:
			b.add_theme_stylebox_override(st, normal)
		for st in ["hover", "focus"]:
			b.add_theme_stylebox_override(st, hover)
		b.queue_redraw()


func _build_info_bar() -> void:
	var bar := Control.new()
	bar.position = Vector2(8, 180)
	bar.size = Vector2(384, 37)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		bar.draw_rect(Rect2(0, 0, bar.size.x, bar.size.y), Color(0.02, 0.03, 0.12, 0.85))
		bar.draw_rect(Rect2(0, 0, bar.size.x, bar.size.y), Color(1.0, 0.82, 0.2, 0.45), false, 1.0))
	add_child(bar)
	name_l = UI.label("", 8, UI.GOLD)
	name_l.position = Vector2(6, 4)
	bar.add_child(name_l)
	price_l = UI.label("", 8, Color.WHITE)
	price_l.size = Vector2(150, 10)
	price_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_l.position = Vector2(228, 4)
	bar.add_child(price_l)
	desc_l = UI.label("", 8, Color(0.75, 0.85, 1.0))
	desc_l.position = Vector2(6, 15)
	bar.add_child(desc_l)
	msg_l = UI.label("", 8, UI.MINT)
	msg_l.position = Vector2(6, 26)
	bar.add_child(msg_l)


# ------------------------------------------------------------------ tabs and grid
func _open_tab(i: int) -> void:
	tab = i
	_restyle_tabs()
	for c in cells:
		if is_instance_valid(c):
			_grid_root.remove_child(c)
			c.queue_free()
	cells.clear()
	cell_items.clear()
	var slot: String = Cosmetics.SLOTS[tab]
	var list := Cosmetics.in_slot(slot)
	for n in list.size():
		var it: Dictionary = list[n]
		var b := _make_cell(it)
		b.position = GRID_POS + Vector2((n % COLS) * (CELL.x + GAP), (n / COLS) * (CELL.y + GAP))
		_grid_root.add_child(b)
		cells.append(b)
		cell_items.append(it)
	_wire_focus()
	# start on the worn item (or the first one) so the preview matches what you see
	var start := 0
	for n in list.size():
		if Game.equipped(slot) == list[n]["id"]:
			start = n
			break
	if not cells.is_empty():
		_select(list[start])
	_refresh_cells()


## Focus (d-pad / stick / arrow keys) follows the REAL on-screen layout:
##   tabs on top, the item grid under them, and BACK at the bottom LEFT, next to the grid.
##   grid: LEFT from the first column -> BACK. DOWN never jumps to BACK any more.
##   BACK: RIGHT -> the grid row next to it, UP -> the first tab.
func _wire_focus() -> void:
	var n := cells.size()
	if n == 0:
		return
	var rows_n := (n + COLS - 1) / COLS
	for i in tab_btns.size():
		var t: Button = tab_btns[i]
		_link(t, "left", tab_btns[maxi(i - 1, 0)])
		_link(t, "right", tab_btns[mini(i + 1, tab_btns.size() - 1)])
		_link(t, "top", t)
		_link(t, "bottom", _cell_near_x(0, t.position.x + t.size.x * 0.5))
	for idx in n:
		var c: Control = cells[idx]
		var col := idx % COLS
		var row := idx / COLS
		_link(c, "left", cells[idx - 1] if col > 0 else back_btn)
		_link(c, "right", cells[idx + 1] if (col < COLS - 1 and idx + 1 < n) else c)
		_link(c, "top", cells[idx - COLS] if row > 0 else _tab_near_x(c.position.x + CELL.x * 0.5))
		var down: Control = c
		if idx + COLS < n:
			down = cells[idx + COLS]
		elif row + 1 < rows_n:
			down = cells[n - 1]   # next row is shorter: land on its last item
		_link(c, "bottom", down)
	# BACK sits left of the grid: RIGHT enters the grid row that lines up with it
	var best_row := 0
	var best_d := INF
	var back_y := back_btn.position.y + 10.0
	for r in rows_n:
		var d := absf(GRID_POS.y + r * (CELL.y + GAP) + CELL.y * 0.5 - back_y)
		if d < best_d:
			best_d = d
			best_row = r
	_link(back_btn, "right", cells[best_row * COLS])
	_link(back_btn, "top", tab_btns[0])
	_link(back_btn, "left", back_btn)
	_link(back_btn, "bottom", back_btn)


func _link(ctl: Control, side: String, target: Control) -> void:
	var path := ctl.get_path_to(target)
	match side:
		"left": ctl.focus_neighbor_left = path
		"right": ctl.focus_neighbor_right = path
		"top": ctl.focus_neighbor_top = path
		"bottom": ctl.focus_neighbor_bottom = path


func _cell_near_x(row: int, x: float) -> Control:
	var best: Control = cells[0]
	var best_d := INF
	for k in COLS:
		var idx := row * COLS + k
		if idx >= cells.size():
			break
		var d := absf((cells[idx] as Control).position.x + CELL.x * 0.5 - x)
		if d < best_d:
			best_d = d
			best = cells[idx]
	return best


func _tab_near_x(x: float) -> Control:
	var best: Control = tab_btns[0]
	var best_d := INF
	for t in tab_btns:
		var d := absf((t as Control).position.x + TAB_W * 0.5 - x)
		if d < best_d:
			best_d = d
			best = t
	return best


func _make_cell(it: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CELL
	b.size = CELL
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	b.draw.connect(func(): _draw_cell(b, it))
	b.pressed.connect(func(): _on_cell(it, b))
	b.focus_entered.connect(func():
		if not _mute_click:
			Audio.play("click")
		_select(it))
	b.mouse_entered.connect(func(): b.grab_focus())
	b.set_meta("item", it)
	_style_cell(b, it)
	return b


func _cell_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s


func _style_cell(b: Button, it: Dictionary) -> void:
	var id: String = it["id"]
	var owned := Game.owns(id)
	var worn: bool = Game.equipped(it["slot"]) == id
	var bg := Color(0.10, 0.12, 0.30)
	var border := Color(0.24, 0.29, 0.62)
	if worn:
		bg = Color(0.30, 0.23, 0.04)
		border = UI.GOLD
	elif owned:
		bg = Color(0.07, 0.20, 0.22)
		border = Color(0.25, 0.65, 0.42)
	var lit := _cell_box(bg.lightened(0.18), Color.WHITE)
	var normal := _cell_box(bg, border)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("pressed", _cell_box(bg.darkened(0.2), UI.GOLD))
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("focus", lit)


func _refresh_cells() -> void:
	for c in cells:
		var it: Dictionary = c.get_meta("item")
		_style_cell(c, it)
		c.queue_redraw()
	_update_info()


func _font() -> Font:
	return UI.font if UI.font else ThemeDB.fallback_font


func _text(b: Control, pos: Vector2, t: String, col: Color) -> void:
	b.draw_string_outline(_font(), pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, UI.INK)
	b.draw_string(_font(), pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


func _draw_cell(b: Button, it: Dictionary) -> void:
	var id: String = it["id"]
	var owned := Game.owns(id)
	var worn: bool = Game.equipped(it["slot"]) == id
	var price: int = it["price"]
	var can_buy: bool = Game.wallet >= price
	var tex: Texture2D = Cosmetics.thumb(it)
	var ts := tex.get_size()
	var tint := Color(1, 1, 1, 1) if (owned or can_buy) else Color(0.62, 0.62, 0.7, 1)
	b.draw_texture(tex, Vector2(roundf((b.size.x - ts.x) * 0.5), 3.0 + roundf((28.0 - ts.y) * 0.5)), tint)
	var by := 36.0
	if owned:
		var t := "WORN" if worn else "OWNED"
		var col := UI.GOLD if worn else UI.MINT
		_text(b, Vector2(roundf((b.size.x - t.length() * 8.0) * 0.5), by), t, col)
	else:
		var t := str(price)
		var w := 10.0 + t.length() * 8.0
		var x := roundf((b.size.x - w) * 0.5)
		b.draw_texture(Cosmetics.coin_icon(), Vector2(x, by - 8.0))
		_text(b, Vector2(x + 10.0, by), t, Color(1.0, 0.95, 0.6) if can_buy else Color(1.0, 0.5, 0.45))
	if worn:
		# little tick in the corner of the worn item
		b.draw_rect(Rect2(b.size.x - 9, 2, 7, 7), UI.GOLD)
		b.draw_rect(Rect2(b.size.x - 8, 5, 2, 2), UI.INK)
		b.draw_rect(Rect2(b.size.x - 6, 6, 2, 2), UI.INK)
		b.draw_rect(Rect2(b.size.x - 4, 4, 2, 2), UI.INK)


# ------------------------------------------------------------------ selection, info, preview
func _select(it: Dictionary) -> void:
	sel = it
	_update_info()
	_update_preview()


func _update_info() -> void:
	if sel.is_empty():
		return
	var id: String = sel["id"]
	var slot: String = sel["slot"]
	var owned := Game.owns(id)
	var worn: bool = Game.equipped(slot) == id
	name_l.text = sel["name"]
	desc_l.text = sel["desc"]
	var price: int = sel["price"]
	var col := UI.MINT
	var m := ""
	if worn:
		price_l.text = "WORN"
		price_l.add_theme_color_override("font_color", UI.GOLD)
		m = "SELECT TO TAKE OFF" if slot in Cosmetics.REMOVABLE else "CURRENTLY WORN"
	elif owned:
		price_l.text = "OWNED"
		price_l.add_theme_color_override("font_color", UI.MINT)
		m = "SELECT TO WEAR"
	else:
		price_l.text = "%d COINS" % price
		var ok: bool = Game.wallet >= price
		price_l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6) if ok else Color(1.0, 0.5, 0.45))
		if ok:
			m = "SELECT TO BUY"
		else:
			m = "NEED %d MORE COINS" % (price - Game.wallet)
			col = Color(1.0, 0.55, 0.5)
	msg_l.text = m
	msg_l.add_theme_color_override("font_color", col)
	if tag_l:
		tag_l.text = "" if owned else "PREVIEW"


func _flash_msg(t: String, col: Color) -> void:
	msg_l.text = t
	msg_l.add_theme_color_override("font_color", col)
	if _msg_tween and _msg_tween.is_valid():
		_msg_tween.kill()
	msg_l.position.x = 6
	_msg_tween = msg_l.create_tween()
	_msg_tween.tween_property(msg_l, "position:x", 10.0, 0.04)
	_msg_tween.tween_property(msg_l, "position:x", 2.0, 0.06)
	_msg_tween.tween_property(msg_l, "position:x", 6.0, 0.04)


func _preview_loadout() -> Dictionary:
	var lo := Game.loadout.duplicate()
	if not sel.is_empty():
		lo[sel["slot"]] = sel["id"]
	return lo


func _update_preview() -> void:
	var lo := _preview_loadout()
	var sg := Cosmetics.sig(lo)
	if sg == _last_sig:
		return
	_last_sig = sg
	var anim := String(ANIM_CYCLE[_anim_i][0])
	hero.sprite_frames = Cosmetics.small_frames(lo)
	hero.play(anim)


func _process(delta: float) -> void:
	if hero == null or hero.sprite_frames == null:
		return
	_anim_t += delta
	if _anim_t >= float(ANIM_CYCLE[_anim_i][1]):
		_anim_t = 0.0
		_anim_i = (_anim_i + 1) % ANIM_CYCLE.size()
		hero.play(String(ANIM_CYCLE[_anim_i][0]))
	# little hop during the jump pose
	var a := String(ANIM_CYCLE[_anim_i][0])
	var hop := 0.0
	if a == "jump":
		hop = -sin(clampf(_anim_t / 0.8, 0.0, 1.0) * PI) * 14.0
	hero.position.y = 90.0 + roundf(hop)
	# trail preview while "moving"
	var lo := _preview_loadout()
	var tid := String(lo.get("trail", ""))
	if tid != "" and (a == "run" or a == "jump"):
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = Cosmetics.trail_rate(tid) * 1.4
			_trail_n += 1
			Cosmetics.spawn_trail(trail_layer, _rng, tid, Vector2(46, hero.position.y), 1, _trail_n, 3.0, 0)
	if hero.animation != a:
		hero.play(a)


# ------------------------------------------------------------------ buying / wearing
func _on_cell(it: Dictionary, cell: Control) -> void:
	var id: String = it["id"]
	var slot: String = it["slot"]
	var center := cell.global_position + cell.size * 0.5
	if Game.owns(id):
		if Game.equipped(slot) == id:
			if slot in Cosmetics.REMOVABLE:
				Game.equip_item(slot, "")
				Audio.play("pipe")
				_refresh_cells()
				_flash_msg("TAKEN OFF", Color(0.75, 0.85, 1.0))
			else:
				Audio.play("bump")
				_flash_msg("ALREADY WORN", Color(0.75, 0.85, 1.0))
		else:
			Game.equip_item(slot, id)
			Audio.play("powerup")
			_refresh_cells()
			_update_preview()
			_flash_msg("EQUIPPED!", UI.MINT)
			UI.burst(self, center, 12, 80.0, [Color(0.5, 1.0, 0.7), Color.WHITE, UI.GOLD])
		return
	var price: int = it["price"]
	if Game.wallet < price:
		Audio.play("bump")
		_flash_msg("NEED %d MORE COINS" % (price - Game.wallet), Color(1.0, 0.55, 0.5))
		return
	# affordable: ask the player first (BUY / CANCEL)
	_open_confirm(it, cell)


## Really buys the item (called only after BUY was pressed in the modal).
func _purchase(it: Dictionary, cell: Control) -> void:
	var id: String = it["id"]
	var slot: String = it["slot"]
	var center := Vector2(200, 112)
	if is_instance_valid(cell):
		center = cell.global_position + cell.size * 0.5
	var err := Game.buy_item(id)
	if err != "":
		Audio.play("bump")
		_refresh_cells()
		_flash_msg(err, Color(1.0, 0.55, 0.5))
		return
	Game.equip_item(slot, id)
	Audio.play("coin")
	Audio.play("oneup")
	_set_wallet(true)
	_refresh_cells()
	_update_preview()
	_flash_msg("PURCHASED!", UI.GOLD)
	UI.burst(self, center, 28, 130.0, [UI.GOLD, Color(1, 0.95, 0.6), Color.WHITE])


# ------------------------------------------------------------------ confirm modal
func _open_confirm(it: Dictionary, cell: Control) -> void:
	if _modal != null:
		return
	_modal_item = it
	_modal_cell = cell
	_modal_unlock = Time.get_ticks_msec() + 180
	Audio.play("select")
	var price: int = it["price"]
	var slot: String = it["slot"]

	var root := Control.new()
	root.size = size
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # swallows every click / tap behind the modal
	add_child(root)
	_modal = root

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.08, 0.62)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	UI.fade_in(dim, 0.0, 0.15)

	var box := Control.new()
	box.size = MODAL_SIZE
	box.position = ((size - MODAL_SIZE) * 0.5).floor()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(func():
		var s := box.size
		box.draw_rect(Rect2(2, 3, s.x, s.y), Color(0, 0, 0, 0.55))
		box.draw_rect(Rect2(0, 0, s.x, s.y), Color(0.05, 0.06, 0.20, 0.99))
		box.draw_rect(Rect2(0, 0, s.x, s.y), UI.GOLD, false, 2.0)
		box.draw_rect(Rect2(4, 4, s.x - 8, s.y - 8), Color(1, 1, 1, 0.07), false, 1.0)
		box.draw_rect(Rect2(2, 2, s.x - 4, 3), Color(1, 1, 1, 0.10))
		box.draw_rect(Rect2(8, 28, s.x - 16, 1), Color(1.0, 0.82, 0.2, 0.35))
		for c in [Vector2(2, 2), Vector2(s.x - 6, 2), Vector2(2, s.y - 6), Vector2(s.x - 6, s.y - 6)]:
			box.draw_rect(Rect2(c.x, c.y, 4, 4), UI.GOLD)
			box.draw_rect(Rect2(c.x + 1, c.y + 1, 2, 2), Color(1, 1, 1, 0.65)))
	root.add_child(box)

	var title := UI.label("BUY %s?" % String(Cosmetics.SLOT_NAMES[slot]), 16, UI.GOLD)
	title.size = Vector2(MODAL_SIZE.x, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(1, 8)
	box.add_child(title)

	# item picture
	var pic := Control.new()
	pic.size = Vector2(48, 40)
	pic.position = Vector2(14, 36)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.draw.connect(func():
		pic.draw_rect(Rect2(0, 0, 48, 40), Color(0.10, 0.12, 0.30))
		var tex: Texture2D = Cosmetics.thumb(it)
		var ts := tex.get_size()
		var k := 2.0 if (ts.x * 2.0 <= 44.0 and ts.y * 2.0 <= 36.0) else 1.0
		var ds := ts * k
		pic.draw_texture_rect(tex, Rect2(Vector2(roundf((48.0 - ds.x) * 0.5), roundf((40.0 - ds.y) * 0.5)), ds), false)
		pic.draw_rect(Rect2(0, 0, 48, 40), UI.GOLD, false, 2.0))
	box.add_child(pic)

	# name / price / balance
	var nm := UI.label(String(it["name"]), 8, UI.GOLD)
	nm.position = Vector2(70, 37)
	box.add_child(nm)
	var coin := TextureRect.new()
	coin.texture = Cosmetics.coin_icon()
	coin.position = Vector2(70, 48)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(coin)
	var pr := UI.label("%d COINS" % price, 8, Color(1.0, 0.95, 0.6))
	pr.position = Vector2(80, 49)
	box.add_child(pr)
	var have := UI.label("YOU HAVE: %d" % Game.wallet, 8, Color(0.75, 0.85, 1.0))
	have.position = Vector2(70, 61)
	box.add_child(have)
	var after := UI.label("AFTER BUY: %d" % (Game.wallet - price), 8, UI.MINT)
	after.position = Vector2(70, 72)
	box.add_child(after)

	# BUY / CANCEL
	var buy_btn := UI.button("BUY", func(): _confirm_buy(), 90)
	buy_btn.position = Vector2(22, 90)
	box.add_child(buy_btn)
	var cancel_btn := UI.button("CANCEL", func(): _close_confirm(), 90)
	cancel_btn.position = Vector2(124, 90)
	box.add_child(cancel_btn)
	UI.wire_focus_grid([[buy_btn, cancel_btn]])
	buy_btn.focus_next = buy_btn.get_path_to(cancel_btn)
	buy_btn.focus_previous = buy_btn.get_path_to(cancel_btn)
	cancel_btn.focus_next = cancel_btn.get_path_to(buy_btn)
	cancel_btn.focus_previous = cancel_btn.get_path_to(buy_btn)
	buy_btn.grab_focus.call_deferred()

	UI.pop_in(box, 0.0, 0.18)


func _confirm_buy() -> void:
	if Time.get_ticks_msec() < _modal_unlock:
		return
	var it := _modal_item
	var cell := _modal_cell
	_close_confirm(true)
	_purchase(it, cell)


## Closes the modal and puts the focus back on the item that opened it.
func _close_confirm(force: bool = false) -> void:
	if _modal == null:
		return
	if not force and Time.get_ticks_msec() < _modal_unlock:
		return
	var m := _modal
	_modal = null
	m.queue_free()
	var cell := _modal_cell
	_modal_cell = null
	if is_instance_valid(cell):
		_mute_click = true
		(cell as Control).grab_focus()
		_mute_click = false


func _unhandled_input(event: InputEvent) -> void:
	if _modal != null:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			_close_confirm()
		get_viewport().set_input_as_handled()
		return
	# L / R style tab switching with Q / E or the shoulder buttons
	var ke := event as InputEventKey
	if ke != null and ke.pressed and not ke.echo:
		if ke.physical_keycode == KEY_Q:
			_step_tab(-1)
			get_viewport().set_input_as_handled()
		elif ke.physical_keycode == KEY_E:
			_step_tab(1)
			get_viewport().set_input_as_handled()
	var jb := event as InputEventJoypadButton
	if jb != null and jb.pressed:
		if jb.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_step_tab(-1)
			get_viewport().set_input_as_handled()
		elif jb.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_step_tab(1)
			get_viewport().set_input_as_handled()


func _step_tab(d: int) -> void:
	var n: int = Cosmetics.SLOTS.size()
	Audio.play("select")
	_open_tab((tab + d + n) % n)
	if not cells.is_empty():
		(cells[0] as Control).grab_focus()
