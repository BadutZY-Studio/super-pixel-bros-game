extends CharacterBody2D
## Cave bat (chapter 2). Flaps in a slow figure-8; when you walk under it, it dives at you and flies back up.
## Stomp it, shoot it with fire, or hit it with a star. Origin = centre of the sprite.

var level
var state := "walk"       # walk (alive) | squish | dead  -> same names the other enemies use
var phase := "patrol"     # patrol | dive | rise
var active := false
var origin := Vector2.ZERO
var target := Vector2.ZERO
var t := 0.0
var timer := 0.0
var cooldown := 1.2

var sprite: AnimatedSprite2D
var shape: CollisionShape2D
var hit_area: Area2D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 0
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Game.make_frames(Game.tex("res://assets/sprites/bat.png"), 16, 16, {
		"fly": {"frames": [0, 1], "fps": 7, "loop": true},
		"squish": {"frames": [2], "fps": 1, "loop": true}})
	sprite.play("fly")
	add_child(sprite)
	shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(10, 9)
	shape.shape = rs
	add_child(shape)
	hit_area = Area2D.new()
	hit_area.collision_layer = 0
	hit_area.collision_mask = 2
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(12, 10)
	hs.shape = hr
	hit_area.add_child(hs)
	add_child(hit_area)
	origin = position
	t = level.rng.randf() * TAU


func _patrol_pos() -> Vector2:
	return origin + Vector2(sin(t * 1.1) * 34.0, sin(t * 2.2) * 7.0)


func _physics_process(delta: float) -> void:
	if state == "dead":
		velocity.y += 900.0 * delta
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
	t += delta
	var p = level.player
	match phase:
		"patrol":
			var old := position.x
			position = _patrol_pos()
			sprite.flip_h = position.x > old
			cooldown -= delta
			if cooldown <= 0.0 and p != null and not p.dead:
				var dx: float = p.global_position.x - global_position.x
				var dy: float = (p.global_position.y - 8.0) - global_position.y
				if absf(dx) < 70.0 and dy > 12.0 and dy < 150.0:
					phase = "dive"
					timer = 0.9
					target = p.global_position + Vector2(0, -8)
					sprite.speed_scale = 1.8
		"dive":
			var to := target - global_position
			sprite.flip_h = to.x > 0.0
			timer -= delta
			if timer <= 0.0 or to.length() < 4.0:
				phase = "rise"
			else:
				global_position += to.normalized() * 115.0 * delta
		"rise":
			global_position = global_position.move_toward(_patrol_pos(), 75.0 * delta)
			if global_position.distance_to(_patrol_pos()) < 3.0:
				phase = "patrol"
				cooldown = 2.2
				sprite.speed_scale = 1.0
	for b in hit_area.get_overlapping_bodies():
		if b.is_in_group("player"):
			_touch(b)
	if global_position.y > 280.0:
		queue_free()


func _touch(p) -> void:
	if p.dead or state != "walk":
		return
	if p.star_t > 0.0:
		die_flip(true)
		return
	var stomp: bool = p.velocity.y > 0.0 and p.global_position.y < global_position.y + 2.0
	if stomp:
		Audio.play("stomp")
		p.bounce()
		level.stomp_score(p, global_position + Vector2(0, -8))
		level.burst(global_position, Color(0.6, 0.4, 0.9), 5, 40.0)
		state = "squish"
		timer = 0.4
		sprite.speed_scale = 1.0
		sprite.play("squish")
		shape.set_deferred("disabled", true)
		hit_area.set_deferred("monitoring", false)
	else:
		p.hurt()


func die_flip(award: bool = true) -> void:
	if state == "dead":
		return
	state = "dead"
	velocity = Vector2(randf_range(-40.0, 40.0), -200.0)
	sprite.flip_v = true
	shape.set_deferred("disabled", true)
	hit_area.set_deferred("monitoring", false)
	collision_layer = 0
	Audio.play("kick")
	if award:
		level.add_score(100, global_position + Vector2(0, -12))
