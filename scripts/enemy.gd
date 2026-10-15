extends CharacterBody2D
## Goomba-like walker and Koopa-like turtle (with kickable shell). Origin at feet.

const GRAV := 900.0

var kind := "goomba"
var level
var dir := -1
var state := "walk"     # walk, squish, shell, shell_move, dead
var active := false
var eh := 12.0
var timer := 0.0
var kick_grace := 0.0

var sprite: AnimatedSprite2D
var shape: CollisionShape2D
var hit_area: Area2D
var hit_shape: CollisionShape2D
var kill_area: Area2D
var f_walk: SpriteFrames
var f_shell: SpriteFrames


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	sprite = AnimatedSprite2D.new()
	add_child(sprite)
	shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	add_child(shape)
	hit_area = Area2D.new()
	hit_area.collision_layer = 0
	hit_area.collision_mask = 2
	hit_shape = CollisionShape2D.new()
	hit_shape.shape = RectangleShape2D.new()
	hit_area.add_child(hit_shape)
	add_child(hit_area)
	kill_area = Area2D.new()
	kill_area.collision_layer = 0
	kill_area.collision_mask = 4
	kill_area.monitoring = false
	var ks := CollisionShape2D.new()
	var kr := RectangleShape2D.new()
	kr.size = Vector2(16, 12)
	ks.shape = kr
	ks.position = Vector2(0, -6)
	kill_area.add_child(ks)
	add_child(kill_area)

	if kind == "goomba":
		f_walk = Game.make_frames(Game.tex("res://assets/sprites/goomba.png"), 16, 16, {
			"walk": {"frames": [0, 1], "fps": 6, "loop": true},
			"squish": {"frames": [2], "fps": 1, "loop": true}})
		sprite.sprite_frames = f_walk
		sprite.offset = Vector2(0, -8)
		_set_size(12.0, 12.0)
		sprite.play("walk")
	else:
		f_walk = Game.make_frames(Game.tex("res://assets/sprites/koopa.png"), 16, 24, {
			"walk": {"frames": [0, 1], "fps": 5, "loop": true}})
		f_shell = Game.make_frames(Game.tex("res://assets/sprites/shell.png"), 16, 16, {
			"idle": {"frames": [0], "fps": 1, "loop": true},
			"spin": {"frames": [1, 2, 3, 2], "fps": 16, "loop": true}})
		sprite.sprite_frames = f_walk
		sprite.offset = Vector2(0, -12)
		_set_size(12.0, 14.0)
		sprite.play("walk")


func _set_size(w: float, h: float) -> void:
	eh = h
	var rs: RectangleShape2D = shape.shape
	rs.size = Vector2(w, h)
	shape.position = Vector2(0, -h * 0.5)
	var hs: RectangleShape2D = hit_shape.shape
	hs.size = Vector2(w + 2.0, h)
	hit_shape.position = Vector2(0, -h * 0.5)


func _physics_process(delta: float) -> void:
	if state == "dead":
		velocity.y += GRAV * delta
		global_position += velocity * delta
		if global_position.y > 320.0:
			queue_free()
		return
	if state == "squish":
		timer -= delta
		if timer <= 0.0:
			queue_free()
		return
	if not active:
		if absf(global_position.x - level.cam_x) < 230.0:
			active = true
		else:
			return
	if kick_grace > 0.0:
		kick_grace -= delta

	var spd := 0.0
	match state:
		"walk":
			spd = 28.0 if kind == "goomba" else 32.0
		"shell_move":
			spd = 190.0
	velocity.x = dir * spd
	velocity.y = minf(velocity.y + GRAV * delta, 400.0)
	move_and_slide()
	if is_on_wall():
		var n := get_wall_normal()
		if n.x != 0.0:
			dir = int(signf(n.x))
		if state == "shell_move":
			Audio.play("bump")
	if kind == "koopa" and state == "walk":
		sprite.flip_h = dir > 0

	for b in hit_area.get_overlapping_bodies():
		if b.is_in_group("player"):
			_touch(b)
	if state == "shell_move" and kill_area.monitoring:
		for b in kill_area.get_overlapping_bodies():
			if b != self and b.is_in_group("enemies") and b.state != "dead":
				b.die_flip(true)
	if global_position.y > 280.0:
		queue_free()


func _touch(p) -> void:
	if p.dead or state == "dead" or state == "squish":
		return
	if p.star_t > 0.0:
		die_flip(true)
		return
	var stomp: bool = p.velocity.y > 0.0 and p.global_position.y < global_position.y - eh + 9.0
	match state:
		"walk":
			if stomp:
				_stomped(p)
			else:
				p.hurt()
		"shell":
			_kick(p, stomp)
		"shell_move":
			if stomp:
				state = "shell"
				sprite.play("idle")
				kill_area.set_deferred("monitoring", false)
				p.bounce()
				Audio.play("stomp")
				level.stomp_score(p, global_position + Vector2(0, -eh))
			elif kick_grace <= 0.0:
				p.hurt()


func _stomped(p) -> void:
	Audio.play("stomp")
	p.bounce()
	level.stomp_score(p, global_position + Vector2(0, -eh))
	level.burst(global_position + Vector2(0, -4), Color(0.9, 0.9, 0.9), 4, 40.0)
	if kind == "goomba":
		state = "squish"
		timer = 0.45
		sprite.play("squish")
		shape.set_deferred("disabled", true)
		hit_area.set_deferred("monitoring", false)
	else:
		state = "shell"
		sprite.sprite_frames = f_shell
		sprite.offset = Vector2(0, -8)
		sprite.flip_h = false
		sprite.play("idle")
		_set_size(12.0, 12.0)


func _kick(p, stomp: bool) -> void:
	dir = 1 if p.global_position.x < global_position.x else -1
	state = "shell_move"
	kick_grace = 0.3
	sprite.play("spin")
	kill_area.set_deferred("monitoring", true)
	global_position.x += dir * 4.0
	Audio.play("kick")
	if stomp:
		p.bounce()
		level.stomp_score(p, global_position + Vector2(0, -eh))


func die_flip(award: bool = true) -> void:
	if state == "dead":
		return
	state = "dead"
	velocity = Vector2(randf_range(-40.0, 40.0), -230.0)
	sprite.flip_v = true
	shape.set_deferred("disabled", true)
	hit_area.set_deferred("monitoring", false)
	kill_area.set_deferred("monitoring", false)
	collision_layer = 0
	Audio.play("kick")
	if award:
		level.add_score(100, global_position + Vector2(0, -16))
