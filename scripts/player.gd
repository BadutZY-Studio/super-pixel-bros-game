extends CharacterBody2D
## The hero: run / jump / stomp / grow / fire. Origin is at the feet.

signal reached_goal

const FireballScript = preload("res://scripts/fireball.gd")
const Cosmetics = preload("res://scripts/cosmetics.gd")

const WALK := 95.0
const RUN := 150.0
const ACCEL := 560.0
const AIR_ACCEL := 400.0
const FRICTION := 640.0
const SKID_DEC := 950.0
const JUMP_V := -345.0
const GRAV := 960.0
const MAX_FALL := 400.0
const COYOTE := 0.09
const BUFFER := 0.12

const ANIMS := {
	"idle": {"frames": [0], "fps": 1, "loop": true},
	"run": {"frames": [1, 2, 3], "fps": 10, "loop": true},
	"jump": {"frames": [4], "fps": 1, "loop": true},
	"skid": {"frames": [5], "fps": 1, "loop": true},
	"die": {"frames": [6], "fps": 1, "loop": true},
}

var level
var state := 0            # 0 small, 1 big, 2 fire
var control := true
var frozen := false
var dead := false
var facing := 1
var invincible := 0.0
var coyote := 0.0
var buffer := 0.0
var auto_walk := false
var pole_mode := false
var pole_bottom := 0.0
var goal_x := 0.0
var fireballs := 0
var stomp_chain := 0
var dead_t := 0.0
var ice := false
var star_t := 0.0          # seconds of star invincibility left
var boosted := false       # launched by a spring: the jump is not cut short when JUMP is released
var _last_vy := 0.0
var _was_floor := false
var _anim := "idle"
var _dust_t := 0.0
var _trail_t := 0.0
var _trail_n := 0

var sprite: AnimatedSprite2D
var shape: CollisionShape2D
var forms: Array = []


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 4.0
	sprite = AnimatedSprite2D.new()
	add_child(sprite)
	shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	add_child(shape)
	# the sprites come from the shop system: skin + suit + hat + face + back item of the saved loadout
	forms = Cosmetics.frames_for(Game.loadout)["frames"]
	set_form(state)


func set_form(s: int) -> void:
	state = s
	var h: float = 16.0 if s == 0 else 32.0
	sprite.sprite_frames = forms[s]
	# the frame is taller than the body (room for hats) and the feet sit on its bottom edge
	sprite.offset = Vector2(0, -Cosmetics.frame_height(s) * 0.5)
	var rs: RectangleShape2D = shape.shape
	rs.size = Vector2(10, h - 2)
	shape.position = Vector2(0, -(h - 2) * 0.5)
	sprite.play(_anim)


func _play(anim_name: String) -> void:
	if _anim != anim_name or not sprite.is_playing():
		_anim = anim_name
		sprite.play(anim_name)


func _physics_process(delta: float) -> void:
	if dead:
		_dead_process(delta)
		return
	if frozen:
		return
	if pole_mode:
		velocity = Vector2.ZERO
		_play("idle")
		sprite.flip_h = false
		global_position.y = minf(global_position.y + 85.0 * delta, pole_bottom)
		if global_position.y >= pole_bottom:
			pole_mode = false
			_after_pole()
		return

	var on_floor := is_on_floor()
	# chapter 2: DOWN on top of a warp pipe goes into the pipe
	if control and on_floor and Input.is_action_just_pressed("down"):
		if level.try_warp(self):
			return
	var dir := 0.0
	var running := false
	if control:
		dir = Input.get_axis("left", "right")
		running = Input.is_action_pressed("run") or Input.is_action_pressed("dash") \
				or (TouchUI.auto_run and TouchUI.shown)
	elif auto_walk:
		dir = 1.0

	# horizontal movement
	var mult: float = 0.4 if ice else 1.0
	var max_speed := RUN if running else WALK
	if auto_walk:
		max_speed = 85.0
	var skidding := false
	if dir != 0.0:
		var acc := (ACCEL if on_floor else AIR_ACCEL) * mult
		if on_floor and signf(velocity.x) != 0.0 and signf(velocity.x) != signf(dir) and absf(velocity.x) > 50.0:
			acc = SKID_DEC * (0.5 if ice else 1.0)
			skidding = true
		velocity.x = move_toward(velocity.x, dir * max_speed, acc * delta)
		if skidding:
			facing = int(signf(velocity.x))
		else:
			facing = int(signf(dir))
	else:
		var fr := (FRICTION if on_floor else 140.0) * mult
		velocity.x = move_toward(velocity.x, 0.0, fr * delta)

	# jumping
	if on_floor:
		coyote = COYOTE
		stomp_chain = 0
	else:
		coyote -= delta
	if control and Input.is_action_just_pressed("jump"):
		buffer = BUFFER
	else:
		buffer -= delta
	if buffer > 0.0 and coyote > 0.0:
		velocity.y = JUMP_V - absf(velocity.x) * 0.12
		buffer = 0.0
		coyote = 0.0
		Audio.play("jump" if state == 0 else "jump_big")
	var g: float = GRAV * level.grav
	var jump_held := control and Input.is_action_pressed("jump")
	if velocity.y >= 0.0:
		boosted = false
	if velocity.y < 0.0 and not jump_held and not boosted:
		g *= 2.4
	velocity.y = minf(velocity.y + g * delta, MAX_FALL)
	_last_vy = velocity.y

	# fireballs
	if state == 2 and control and (Input.is_action_just_pressed("run") or Input.is_action_just_pressed("fire")) and fireballs < 2:
		var fb = FireballScript.new()
		fb.dir = facing
		fb.owner_player = self
		fb.level = level
		fb.position = global_position + Vector2(facing * 8, -16)
		level.entities.add_child(fb)
		fireballs += 1
		Audio.play("fireball")

	move_and_slide()

	# head bump on blocks
	var best = null
	var best_d := 999.0
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_normal().y > 0.7:
			var o = col.get_collider()
			if o != null and o.has_method("bump"):
				var d: float = absf(o.global_position.x - global_position.x)
				if d < best_d:
					best_d = d
					best = o
	if best != null:
		best.bump(self)

	# landing dust
	if is_on_floor() and not _was_floor and _last_vy > 180.0:
		level.dust(global_position)
	_was_floor = is_on_floor()
	if is_on_floor() and absf(velocity.x) > 110.0:
		_dust_t -= delta
		if _dust_t <= 0.0:
			_dust_t = 0.12
			level.dust(global_position + Vector2(-facing * 4, 0), 1)

	# level bounds
	if control or auto_walk:
		var left: float = level.cam_x - 200.0 + 7.0
		if global_position.x < left:
			global_position.x = left
			velocity.x = maxf(velocity.x, 0.0)
	global_position.x = minf(global_position.x, level.cols * 16.0 - 8.0)

	if auto_walk and global_position.x >= goal_x:
		auto_walk = false
		visible = false
		velocity = Vector2.ZERO
		reached_goal.emit()

	# trail effect of the shop (only while moving)
	var trail_id: String = Game.equipped("trail")
	if trail_id != "" and level.fx_root != null and (absf(velocity.x) > 25.0 or not is_on_floor()):
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = Cosmetics.trail_rate(trail_id)
			_trail_n += 1
			Cosmetics.spawn_trail(level.fx_root, level.rng, trail_id, global_position, facing, _trail_n)

	# star power: rainbow body, enemies die on touch
	if star_t > 0.0:
		star_t -= delta
		sprite.modulate = Color.from_hsv(fposmod(Time.get_ticks_msec() / 280.0, 1.0), 0.5, 1.0)
		if star_t <= 0.0:
			star_t = 0.0
			sprite.modulate = Color.WHITE

	# invincibility flicker
	if invincible > 0.0:
		invincible -= delta
		sprite.visible = (int(Time.get_ticks_msec() / 60) % 2) == 0
		if invincible <= 0.0:
			sprite.visible = true

	# animation
	if not is_on_floor():
		_play("jump")
	elif skidding:
		_play("skid")
	elif absf(velocity.x) > 8.0:
		_play("run")
		sprite.speed_scale = clampf(absf(velocity.x) / WALK, 0.6, 2.2)
	else:
		_play("idle")
	if _anim != "run":
		sprite.speed_scale = 1.0
	sprite.flip_h = facing < 0

	if global_position.y > 250.0:
		die()


## Spring pad: a big launch (see spring.gd).
func spring_launch(v: float) -> void:
	velocity.y = v
	boosted = true
	coyote = 0.0
	buffer = 0.0


## Entering / leaving a warp pipe: the hero is frozen, hidden behind the pipe tiles and cannot be hit.
func begin_warp() -> void:
	frozen = true
	velocity = Vector2.ZERO
	z_index = -1
	shape.set_deferred("disabled", true)
	_play("idle")
	sprite.flip_h = false


func end_warp() -> void:
	frozen = false
	z_index = 0
	velocity = Vector2.ZERO
	shape.set_deferred("disabled", false)
	invincible = maxf(invincible, 0.4)


func bounce() -> void:
	velocity.y = -310.0 if Input.is_action_pressed("jump") else -200.0


func hurt() -> void:
	if dead or invincible > 0.0 or star_t > 0.0 or pole_mode or level.finished:
		return
	if state > 0:
		Audio.play("pipe")
		set_form(0)
		invincible = 2.0
		velocity.y = -150.0
	else:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	control = false
	auto_walk = false
	star_t = 0.0
	sprite.modulate = Color.WHITE
	state = 0
	set_form(0)
	sprite.visible = true
	_play("die")
	sprite.flip_h = false
	shape.set_deferred("disabled", true)
	velocity = Vector2(0, -330.0)
	dead_t = 0.0
	Audio.stop_music()
	Audio.play("die")
	level.on_player_dying()
	await get_tree().create_timer(2.6).timeout
	level.player_died()


func _dead_process(delta: float) -> void:
	dead_t += delta
	if dead_t < 0.45:
		return
	velocity.y += GRAV * 0.8 * delta
	global_position += velocity * delta


func powerup(kind: String) -> void:
	if dead:
		return
	Audio.play("powerup")
	if kind == "star":
		star_t = 9.0
		level.add_score(1000, global_position + Vector2(0, -34))
		return
	if kind == "mushroom":
		if state == 0:
			_transform(1)
		else:
			level.add_score(1000, global_position + Vector2(0, -32))
	elif kind == "flower":
		if state < 2:
			_transform(2)
		else:
			level.add_score(1000, global_position + Vector2(0, -32))


func _transform(to_state: int) -> void:
	frozen = true
	var from := state
	for i in 6:
		set_form(to_state if i % 2 == 0 else from)
		await get_tree().create_timer(0.07).timeout
	set_form(to_state)
	frozen = false
	level.add_score(1000, global_position + Vector2(0, -34))


func start_pole(x: float, bottom_y: float) -> void:
	control = false
	auto_walk = false
	pole_mode = true
	pole_bottom = bottom_y
	global_position.x = x
	velocity = Vector2.ZERO
	invincible = 0.0
	sprite.visible = true


func _after_pole() -> void:
	await get_tree().create_timer(0.45).timeout
	global_position.x += 14.0
	facing = 1
	auto_walk = true
