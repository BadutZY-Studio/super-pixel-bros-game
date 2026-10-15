extends Node2D
## Builds a level from its ASCII map and runs the gameplay loop.

const T := 16
const ROWS := 14
const SOLID := "GXTtLlYyRg"

const BlockScript = preload("res://scripts/block.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const PiranhaScript = preload("res://scripts/piranha.gd")
const PlayerScript = preload("res://scripts/player.gd")
const ItemScript = preload("res://scripts/item.gd")
const TileLayerScript = preload("res://scripts/tile_layer.gd")
const PlatformScript = preload("res://scripts/platform.gd")
const DebrisScript = preload("res://scripts/debris.gd")
const ScrollerScript = preload("res://scripts/scroller.gd")
const HudScript = preload("res://scripts/hud.gd")
const BatScript = preload("res://scripts/bat.gd")
const SpringScript = preload("res://scripts/spring.gd")
const CrusherScript = preload("res://scripts/crusher.gd")
const FirebarScript = preload("res://scripts/firebar.gd")
const FallPlatformScript = preload("res://scripts/falling_platform.gd")

const STOMP_SCORES := [100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000]

var data: Dictionary
var theme_name := "grass"
var theme: Dictionary
var rows: Array
var cols := 0
var tile_tex: Texture2D

var player
var camera: Camera2D
var hud
var entities: Node2D
var fx_root: Node2D
var cam_x := 200.0
var time_left := 300.0
var running := false
var finished := false
var hurry_played := false

var spawn := Vector2(40, 192)
var flag_x := 0.0
var flag_top_y := 0.0
var flag_base_y := 0.0
var flag_sprite: Sprite2D
var castle_door_x := 0.0
var scrollers: Array = []
var rng := RandomNumberGenerator.new()

# --- chapter 2: warp pipes, bonus rooms, low gravity
var main_cols := 0                    # columns of the real level; bonus rooms (25 columns each) are appended after it
var grav := 1.0                       # gravity multiplier of the theme (space = floaty)
var warps := {}                       # Vector2i(pipe left col, pipe top row) -> Vector2i of the pipe at the other end
var warp_arrows: Array = []           # [Sprite2D, Vector2i key]
var warping := false
var fade_rect: ColorRect


func _ready() -> void:
	data = Game.LevelsData.DATA[Game.current_level]
	theme_name = data["theme"]
	theme = Game.LevelsData.THEMES[theme_name]
	rows = data["rows"]
	cols = rows[0].length()
	main_cols = int(data.get("main_cols", cols))
	grav = float(theme.get("grav", 1.0))
	for w in data.get("warps", []):
		warps[Vector2i(int(w[0]), int(w[1]))] = Vector2i(int(w[2]), int(w[3]))
		warps[Vector2i(int(w[2]), int(w[3]))] = Vector2i(int(w[0]), int(w[1]))
	time_left = float(data["time"])
	rng.seed = 1234 + Game.current_level * 77
	tile_tex = Game.tex("res://assets/tiles/tiles_%s.png" % theme_name)

	_build_background()
	_build_decor()
	entities = Node2D.new()
	entities.name = "Entities"
	_build_world()
	add_child(entities)
	fx_root = Node2D.new()
	fx_root.z_index = 20
	add_child(fx_root)
	_build_player()
	_build_camera()
	_build_fx_layer()
	_build_warp_extras()
	hud = HudScript.new()
	hud.level = self
	add_child(hud)
	_start_sequence()


# ------------------------------------------------------------------ helpers
func _cell(c: int, r: int) -> String:
	if r < 0 or r >= ROWS or c < 0 or c >= cols:
		return "."
	return rows[r][c]


func _is_solid(c: int, r: int) -> bool:
	return SOLID.contains(_cell(c, r)) and _cell(c, r) != "."


# ------------------------------------------------------------------ background
func _build_background() -> void:
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	bg.add_child(Game.make_sky(theme["sky_top"], theme["sky_bot"]))
	var sky_path := "res://assets/bg/bg_%s_sky.png" % theme_name
	if ResourceLoader.exists(sky_path):
		_add_scroller(bg, Game.tex(sky_path), 0.03, 180.0)
	if theme_name == "night":
		_add_scroller(bg, Game.tex("res://assets/bg/bg_night_moon.png"), 0.0, 180.0)
	_add_scroller(bg, Game.tex("res://assets/bg/bg_%s_far.png" % theme_name), theme["far"], 205.0)
	_add_scroller(bg, Game.tex("res://assets/bg/bg_%s_near.png" % theme_name), theme["near"], 208.0)


func _add_scroller(parent: Node, t: Texture2D, f: float, bottom: float) -> void:
	var s = ScrollerScript.new()
	parent.add_child(s)
	s.setup(t, f, bottom)
	scrollers.append(s)


func _build_fx_layer() -> void:
	var fx: String = theme["fx"]
	if fx == "":
		return
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var p := CPUParticles2D.new()
	p.position = Vector2(200, -4)
	p.amount = 60
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(220, 2)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	match fx:
		"snow":
			p.direction = Vector2(-0.3, 1)
			p.spread = 20.0
			p.gravity = Vector2(-4, 14)
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 22.0
			p.color = Color(1, 1, 1, 0.9)
		"embers":
			p.position = Vector2(200, 228)
			p.direction = Vector2(0, -1)
			p.spread = 25.0
			p.gravity = Vector2(0, -6)
			p.initial_velocity_min = 15.0
			p.initial_velocity_max = 40.0
			p.color = Color(1.0, 0.55, 0.15, 0.85)
			p.lifetime = 5.0
		"dust":
			p.direction = Vector2(0, 1)
			p.spread = 180.0
			p.gravity = Vector2(0, 2)
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 8.0
			p.color = Color(0.6, 0.8, 1.0, 0.5)
			p.emission_rect_extents = Vector2(220, 110)
			p.position = Vector2(200, 112)
	layer.add_child(p)


func _build_decor() -> void:
	var decor := Node2D.new()
	decor.z_index = -3
	add_child(decor)
	var gd: Array = theme["gdecor"]
	if gd.size() > 0:
		var c := 3
		while c < cols - 16:
			var ground_row := -1
			for r in range(ROWS):
				if _cell(c, r) == "G":
					ground_row = r
					break
			if ground_row == 12 and _cell(c + 1, 12) == "G" and _cell(c + 2, 12) == "G" and _cell(c, 11) == "." and _cell(c + 1, 11) == ".":
				var nm: String = gd[rng.randi() % gd.size()]
				var t := Game.tex("res://assets/sprites/%s.png" % nm)
				var s := Sprite2D.new()
				s.texture = t
				s.centered = false
				s.position = Vector2(c * T, SURF_Y() - t.get_height())
				decor.add_child(s)
				c += int(ceil(t.get_width() / 16.0)) + rng.randi_range(2, 7)
			else:
				c += 1
	var sd: Array = theme["sdecor"]
	if sd.size() > 0:
		var x := 40.0
		while x < cols * T:
			var nm2: String = sd[rng.randi() % sd.size()]
			var s2 := Sprite2D.new()
			s2.texture = Game.tex("res://assets/sprites/%s.png" % nm2)
			s2.centered = false
			s2.modulate = theme["cloud"]
			s2.position = Vector2(x, rng.randf_range(14.0, 80.0))
			s2.z_index = -4
			decor.add_child(s2)
			x += rng.randf_range(90.0, 200.0)


func SURF_Y() -> float:
	return 12.0 * T


# ------------------------------------------------------------------ world
func _build_world() -> void:
	var tiles = TileLayerScript.new()
	tiles.tex = tile_tex
	add_child(tiles)

	# bonus rooms (appended after the real level) get a dark backdrop that hides the sky
	if cols > main_cols:
		var back := ColorRect.new()
		back.color = Color(0.05, 0.05, 0.13)
		back.position = Vector2(main_cols * T, 0)
		back.size = Vector2((cols - main_cols) * T, ROWS * T)
		back.z_index = -3
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(back)
		for k in range(main_cols * T + 24, cols * T - 16, 48):
			var glow := ColorRect.new()
			glow.color = Color(0.09, 0.09, 0.2)
			glow.position = Vector2(k, 48)
			glow.size = Vector2(24, 144)
			glow.z_index = -3
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(glow)

	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	add_child(ground)
	var oneway := StaticBody2D.new()
	oneway.collision_layer = 1
	oneway.collision_mask = 0
	add_child(oneway)

	for r in ROWS:
		# solid runs
		var run_start := -1
		for c in range(cols + 1):
			var solid := c < cols and _is_solid(c, r)
			if solid and run_start < 0:
				run_start = c
			elif not solid and run_start >= 0:
				_add_rect(ground, run_start * T, r * T, (c - run_start) * T, T)
				run_start = -1
		# one-way runs
		run_start = -1
		for c in range(cols + 1):
			var ow := c < cols and _cell(c, r) == "-"
			if ow and run_start < 0:
				run_start = c
			elif not ow and run_start >= 0:
				var cs := _add_rect(oneway, run_start * T, r * T, (c - run_start) * T, 6)
				cs.one_way_collision = true
				run_start = -1
		for c in cols:
			var ch := _cell(c, r)
			var center := Vector2(c * T + 8, r * T + 8)
			var feet := Vector2(c * T + 8, (r + 1) * T)
			match ch:
				"G":
					var above := _cell(c, r - 1)
					var top := not (SOLID.contains(above) and above != ".")
					tiles.cells.append([c, r, 0 if top else 1])
				"X":
					tiles.cells.append([c, r, 3])
				"Y":
					tiles.cells.append([c, r, 5])
				"y":
					tiles.cells.append([c, r, 6])
				"g":
					var gabove := _cell(c, r - 1)
					tiles.cells.append([c, r, 1 if (SOLID.contains(gabove) and gabove != ".") else 0])
				"R":
					tiles.cells.append([c, r, 3])
					var fbar = FirebarScript.new()
					fbar.level = self
					fbar.position = center
					entities.add_child(fbar)
				"A":
					var bat = BatScript.new()
					bat.level = self
					bat.position = center
					entities.add_child(bat)
				"J":
					var spr = SpringScript.new()
					spr.level = self
					spr.position = feet
					entities.add_child(spr)
				"*":
					_spawn_block(center, "q", "star")
				"f":
					var fp = FallPlatformScript.new()
					fp.position = center
					add_child(fp)
				"O":
					var cr = CrusherScript.new()
					cr.level = self
					cr.position = Vector2(c * T + 8, r * T + 12)
					entities.add_child(cr)
				"T":
					tiles.cells.append([c, r, 5])
				"t":
					tiles.cells.append([c, r, 6])
				"L":
					tiles.cells.append([c, r, 7])
				"l":
					tiles.cells.append([c, r, 8])
				"V":
					tiles.cells.append([c, r, 9])
				"v":
					tiles.cells.append([c, r, 10])
				"-":
					tiles.cells.append([c, r, 15])
				"S":
					tiles.cells.append([c, r, 14])
					_add_hazard(Vector2(c * T + 3, r * T + 8), Vector2(10, 8), false)
				"B":
					_spawn_block(center, "brick", "coin")
				"?":
					_spawn_block(center, "q", "coin")
				"M":
					_spawn_block(center, "q", "powerup")
				"C":
					_spawn_item("coin", center)
				"E":
					_spawn_enemy("goomba", feet)
				"K":
					_spawn_enemy("koopa", feet)
				"F":
					var pir = PiranhaScript.new()
					pir.level = self
					pir.position = Vector2((c + 1) * T, (r + 1) * T)
					entities.add_child(pir)
				"P":
					spawn = feet
				"Z":
					_build_flag(c, r)
				"D":
					_build_castle(c, r)
				"c":
					_build_checkpoint(feet)
				"N":
					_spawn_platform(center, true, 48.0, 1.3)
				"n":
					_spawn_platform(center, true, 64.0, 1.0)
				"W":
					_spawn_platform(center, false, 40.0, 1.5)
	tiles.queue_redraw()

	# lava: merge horizontal runs per row
	for r in ROWS:
		var start := -1
		for c in range(cols + 1):
			var is_lava := c < cols and (_cell(c, r) == "V" or _cell(c, r) == "v")
			if is_lava and start < 0:
				start = c
			elif not is_lava and start >= 0:
				_add_hazard(Vector2(start * T, r * T + 5), Vector2((c - start) * T, 11), true)
				start = -1


func _add_rect(body: StaticBody2D, x: float, y: float, w: float, h: float) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w, h)
	cs.shape = rs
	cs.position = Vector2(x + w * 0.5, y + h * 0.5)
	body.add_child(cs)
	return cs


func _add_hazard(top_left: Vector2, size: Vector2, deadly: bool) -> void:
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	cs.position = top_left + size * 0.5
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(func(b):
		if b.is_in_group("player"):
			if deadly:
				b.call_deferred("die")
			else:
				b.call_deferred("hurt"))


func _spawn_block(pos: Vector2, kind: String, content: String) -> void:
	var b = BlockScript.new()
	b.level = self
	b.kind = kind
	b.content = content
	b.position = pos
	add_child(b)


func _spawn_item(kind: String, pos: Vector2, emerge: bool = false) -> Node:
	var it = ItemScript.new()
	it.kind = kind
	it.level = self
	it.emerge = emerge
	it.position = pos
	entities.add_child(it)
	return it


func _spawn_enemy(kind: String, pos: Vector2) -> void:
	var e = EnemyScript.new()
	e.kind = kind
	e.level = self
	e.position = pos
	entities.add_child(e)


func _spawn_platform(pos: Vector2, horizontal: bool, rng_px: float, spd: float) -> void:
	var p = PlatformScript.new()
	p.horizontal = horizontal
	p.range_px = rng_px
	p.speed = spd
	p.position = pos
	add_child(p)


func _build_flag(c: int, r: int) -> void:
	flag_x = c * T + 7
	flag_base_y = (r + 1) * T
	flag_top_y = flag_base_y - 9 * T
	var pole := ColorRect.new()
	pole.color = Color(0.85, 0.9, 0.95)
	pole.position = Vector2(flag_x, flag_top_y)
	pole.size = Vector2(2, flag_base_y - flag_top_y)
	pole.z_index = -1
	add_child(pole)
	var shade := ColorRect.new()
	shade.color = Color(0.45, 0.5, 0.6)
	shade.position = Vector2(flag_x + 1, flag_top_y)
	shade.size = Vector2(1, flag_base_y - flag_top_y)
	shade.z_index = -1
	add_child(shade)
	var ball := Sprite2D.new()
	ball.texture = Game.tex("res://assets/sprites/flag_ball.png")
	ball.position = Vector2(flag_x + 1, flag_top_y - 3)
	add_child(ball)
	flag_sprite = Sprite2D.new()
	flag_sprite.texture = Game.tex("res://assets/sprites/flag.png")
	flag_sprite.position = Vector2(flag_x - 7, flag_top_y + 10)
	flag_sprite.z_index = -1
	add_child(flag_sprite)
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(6, flag_base_y - flag_top_y)
	cs.shape = rs
	cs.position = Vector2(flag_x + 1, (flag_top_y + flag_base_y) * 0.5)
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(_on_flag)


func _build_castle(c: int, r: int) -> void:
	var s := Sprite2D.new()
	s.texture = Game.tex("res://assets/sprites/castle.png")
	s.centered = false
	s.position = Vector2(c * T, (r + 1) * T - 80)
	s.z_index = -2
	add_child(s)
	castle_door_x = c * T + 40.0


func _build_checkpoint(feet: Vector2) -> void:
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = Game.make_frames(Game.tex("res://assets/sprites/checkpoint.png"), 16, 32, {
		"off": {"frames": [0], "fps": 1, "loop": true},
		"on": {"frames": [1], "fps": 1, "loop": true}})
	spr.offset = Vector2(0, -16)
	spr.position = feet
	spr.z_index = -1
	var reached: bool = Game.checkpoints.has(Game.current_level) and Game.checkpoints[Game.current_level].x >= feet.x - 1.0
	spr.play("on" if reached else "off")
	add_child(spr)
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(12, 32)
	cs.shape = rs
	cs.position = feet + Vector2(0, -16)
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(func(b):
		if b.is_in_group("player") and spr.animation != "on":
			spr.play("on")
			Game.checkpoints[Game.current_level] = feet
			Audio.play("checkpoint")
			popup("CHECKPOINT", feet + Vector2(0, -36), Color(0.5, 1.0, 0.6)))


# ------------------------------------------------------------------ player / camera
func _build_player() -> void:
	player = PlayerScript.new()
	player.level = self
	player.state = Game.player_state
	player.ice = theme_name == "snow"
	var start := spawn
	if Game.checkpoints.has(Game.current_level):
		start = Game.checkpoints[Game.current_level]
		start.x += 2.0
	player.position = start
	player.goal_x = castle_door_x if castle_door_x > 0.0 else flag_x + 60.0
	player.reached_goal.connect(_on_reached_goal)
	player.frozen = true
	add_child(player)
	cam_x = _cam_for(start.x)


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_right = cols * T
	camera.limit_top = 0
	camera.limit_bottom = 224
	camera.position_smoothing_enabled = false
	camera.position = Vector2(cam_x, 112)
	add_child(camera)
	camera.make_current()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	if not player.dead and not finished:
		if player.global_position.x >= main_cols * T:
			cam_x = _cam_for(player.global_position.x)      # bonus room: fixed screen
		elif not warping:
			var want := clampf(player.global_position.x + 8.0, 200.0, main_cols * T - 200.0)
			if want > cam_x:
				cam_x = lerpf(cam_x, want, 0.25)
	elif finished and not player.dead:
		var want2 := clampf(player.global_position.x, 200.0, main_cols * T - 200.0)
		cam_x = maxf(cam_x, lerpf(cam_x, want2, 0.1))
	camera.position = Vector2(roundf(cam_x), 112.0)
	for s in scrollers:
		s.scroll = cam_x - 200.0
	_update_warp_arrows()

	if running and not finished and not player.dead:
		time_left -= delta * 1.4
		if time_left <= 100.0 and not hurry_played:
			hurry_played = true
			Audio.play("hurry")
		if time_left <= 0.0:
			time_left = 0.0
			player.die()


## Asked by TouchUI every frame: are the on-screen buttons wanted right now?
func touch_active() -> bool:
	return running and not finished and player != null and not player.dead \
		and hud != null and not hud.paused


# ------------------------------------------------------------------ chapter 2: warp pipes
## Camera centre for a given player x: the real level scrolls, every bonus room is one fixed screen.
func _cam_for(px: float) -> float:
	var main_px := float(main_cols * T)
	if px >= main_px:
		var idx := int((px - main_px) / 400.0)
		return main_px + idx * 400.0 + 200.0
	return clampf(px + 8.0, 200.0, main_px - 200.0)


func _build_warp_extras() -> void:
	var fl := CanvasLayer.new()
	fl.layer = 15
	add_child(fl)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.size = Vector2(400, 224)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(fade_rect)
	var tex := Game.tex("res://assets/sprites/pipe_arrow.png")
	for k in warps:
		var a := Sprite2D.new()
		a.texture = tex
		a.hframes = 2
		a.position = Vector2(k.x * T + T, k.y * T - 9)
		a.z_index = 2
		a.visible = false
		add_child(a)
		warp_arrows.append([a, k])


## Shows the bobbing arrow above a warp pipe while the hero stands on top of it.
func _update_warp_arrows() -> void:
	if player == null:
		return
	var bob := sin(Time.get_ticks_msec() / 130.0) * 1.5
	for e in warp_arrows:
		var a: Sprite2D = e[0]
		var k: Vector2i = e[1]
		var near: bool = (not player.dead) and (not warping) and running and absf(player.global_position.x - (k.x * T + T)) < 26.0 \
				and absf(player.global_position.y - k.y * T) < 6.0
		a.visible = near
		if near:
			a.position.y = k.y * T - 9 + bob
			a.frame = (Time.get_ticks_msec() / 200) % 2


## Called by the player when DOWN is pressed on the ground. True when a pipe was entered.
func try_warp(p) -> bool:
	if warping or finished or not running or p.dead:
		return false
	for k in warps:
		var left: float = k.x * T
		if absf(p.global_position.y - k.y * T) < 3.0 and p.global_position.x > left + 5.0 and p.global_position.x < left + 2.0 * T - 5.0:
			_do_warp(p, warps[k])
			return true
	return false


func _fade_to(a: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", a, dur)
	await tw.finished


func _do_warp(p, dest: Vector2i) -> void:
	warping = true
	p.begin_warp()
	Audio.play("pipe")
	var sink := create_tween()
	sink.tween_property(p, "global_position:y", p.global_position.y + 20.0, 0.45)
	await sink.finished
	await _fade_to(1.0, 0.16)
	var dx := float(dest.x * T + T)
	var dtop := float(dest.y * T)
	cam_x = _cam_for(dx)
	camera.position = Vector2(roundf(cam_x), 112.0)
	for sc in scrollers:
		sc.scroll = cam_x - 200.0
	p.global_position = Vector2(dx, dtop + 20.0)
	await get_tree().create_timer(0.12).timeout
	_fade_to(0.0, 0.2)
	Audio.play("pipe")
	var rise := create_tween()
	rise.tween_property(p, "global_position:y", dtop, 0.45)
	await rise.finished
	p.end_warp()
	warping = false


# ------------------------------------------------------------------ flow
func _start_sequence() -> void:
	await hud.show_intro()
	running = true
	player.frozen = false
	player.control = true
	Audio.play_music(theme["music"])


func on_player_dying() -> void:
	running = false


func _exit_tree() -> void:
	# whatever way the level ends (death, clear, menu, quit) the collected coins are written to disk
	Game.flush_wallet()


func player_died() -> void:
	Game.flush_wallet()
	Game.lives -= 1
	Game.player_state = 0
	if Game.lives <= 0:
		Audio.play("gameover")
		hud.show_gameover()
	else:
		UI.go("res://scenes/level.tscn")


func _on_flag(body: Node) -> void:
	if finished or not body.is_in_group("player") or body.dead:
		return
	finished = true
	running = false
	var height: float = flag_base_y - body.global_position.y
	var pts := 100
	if height > 120.0:
		pts = 5000
	elif height > 90.0:
		pts = 2000
	elif height > 60.0:
		pts = 800
	elif height > 30.0:
		pts = 400
	add_score(pts, Vector2(flag_x + 12, body.global_position.y - 20))
	Audio.stop_music()
	Audio.play("flag")
	body.start_pole(flag_x - 5.0, flag_base_y)
	var dur: float = maxf(0.3, (flag_base_y - body.global_position.y) / 85.0)
	var tw := create_tween()
	tw.tween_property(flag_sprite, "position:y", flag_base_y - 14.0, dur)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.state != "dead":
			e.die_flip(false)


func _on_reached_goal() -> void:
	Audio.play("win")
	Game.player_state = player.state
	await get_tree().create_timer(0.8).timeout
	var bonus := int(time_left) * 50
	hud.show_complete(bonus)


# ------------------------------------------------------------------ gameplay API
func add_score(n: int, pos: Vector2) -> void:
	Game.score += n
	popup(str(n), pos)


func stomp_score(p, pos: Vector2) -> void:
	p.stomp_chain += 1
	var idx: int = p.stomp_chain - 1
	if idx >= STOMP_SCORES.size():
		Game.lives += 1
		Audio.play("oneup")
		popup("1UP", pos, Color(0.4, 1.0, 0.4))
	else:
		add_score(STOMP_SCORES[idx], pos)


func collect_coin(pos: Vector2) -> void:
	Game.coins += 1
	Game.earn_coins(1)   # shop wallet (kept for good, whether or not the level is finished)
	Game.score += 200
	Audio.play("coin")
	burst(pos, Color(1.0, 0.85, 0.2), 4, 40.0)
	if Game.coins >= 100:
		Game.coins -= 100
		Game.lives += 1
		Audio.play("oneup")
		popup("1UP", pos + Vector2(0, -10), Color(0.4, 1.0, 0.4))


func spawn_coin_pop(block_pos: Vector2) -> void:
	_spawn_item("coin_pop", block_pos + Vector2(0, -16))
	Game.coins += 1
	Game.earn_coins(1)
	Game.score += 200
	if Game.coins >= 100:
		Game.coins -= 100
		Game.lives += 1
		Audio.play("oneup")


func spawn_powerup(block_pos: Vector2, player_state: int) -> void:
	_spawn_item("mushroom" if player_state == 0 else "flower", block_pos, true)


func spawn_star(block_pos: Vector2) -> void:
	_spawn_item("star", block_pos, true)


func kill_on_top(block_pos: Vector2) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.state == "dead":
			continue
		if absf(e.global_position.x - block_pos.x) < 14.0 and absf(e.global_position.y - (block_pos.y - 8.0)) < 10.0:
			e.die_flip(true)


func debris(pos: Vector2, tex: Texture2D) -> void:
	for q in 4:
		var d = DebrisScript.new()
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(2 * 16 + (q % 2) * 8, (q / 2) * 8, 8, 8)
		d.texture = at
		d.position = pos + Vector2((q % 2) * 8 - 4, (q / 2) * 8 - 4)
		d.vel = Vector2((q % 2) * 110 - 55 + rng.randf_range(-15, 15), -230 + (q / 2) * 60)
		fx_root.add_child(d)


func burst(pos: Vector2, color: Color, n: int, speed: float) -> void:
	for i in n:
		var r := ColorRect.new()
		r.color = color
		r.size = Vector2(2, 2)
		r.position = pos
		fx_root.add_child(r)
		var ang := rng.randf() * TAU
		var tgt := pos + Vector2(cos(ang), sin(ang) - 0.5) * speed * rng.randf_range(0.4, 1.0) * 0.5
		var tw := r.create_tween()
		tw.set_parallel(true)
		tw.tween_property(r, "position", tgt, 0.4).set_ease(Tween.EASE_OUT)
		tw.tween_property(r, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(r.queue_free)


func dust(pos: Vector2, n: int = 3) -> void:
	for i in n:
		var r := ColorRect.new()
		r.color = Color(1, 1, 1, 0.7)
		r.size = Vector2(2, 2)
		r.position = pos + Vector2(rng.randf_range(-4, 4), -2)
		fx_root.add_child(r)
		var tw := r.create_tween()
		tw.set_parallel(true)
		tw.tween_property(r, "position", r.position + Vector2(rng.randf_range(-8, 8), -rng.randf_range(2, 8)), 0.3)
		tw.tween_property(r, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(r.queue_free)


func popup(text: String, pos: Vector2, color: Color = Color.WHITE) -> void:
	var l := UI.label(text, 8, color)
	l.position = pos + Vector2(-text.length() * 4, -8)
	fx_root.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 28.0, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)
