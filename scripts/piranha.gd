extends Area2D
## Piranha plant that pops out of a pipe. Origin = top-centre of the pipe.

var level
var sprite: AnimatedSprite2D
var shape: CollisionShape2D
var rise := 0.0
var phase := "hidden"
var timer := 1.2
var dead := false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	z_index = -1
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Game.make_frames(Game.tex("res://assets/sprites/piranha.png"), 16, 24, {
		"bite": {"frames": [0, 1], "fps": 5, "loop": true}})
	sprite.offset = Vector2(0, -12)
	sprite.play("bite")
	add_child(sprite)
	shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(10, 16)
	shape.shape = rs
	add_child(shape)
	_apply()


func _apply() -> void:
	sprite.position.y = (1.0 - rise) * 24.0
	shape.position.y = -12.0 + (1.0 - rise) * 24.0


func _physics_process(delta: float) -> void:
	if dead:
		return
	if absf(global_position.x - level.cam_x) > 260.0:
		return
	timer -= delta
	match phase:
		"hidden":
			rise = 0.0
			if timer <= 0.0:
				if absf(level.player.global_position.x - global_position.x) < 32.0:
					timer = 0.5
				else:
					phase = "up"
					timer = 0.6
		"up":
			rise = 1.0 - clampf(timer / 0.6, 0.0, 1.0)
			if timer <= 0.0:
				phase = "stay"
				timer = 1.4
		"stay":
			rise = 1.0
			if timer <= 0.0:
				phase = "down"
				timer = 0.6
		"down":
			rise = clampf(timer / 0.6, 0.0, 1.0)
			if timer <= 0.0:
				phase = "hidden"
				timer = 1.6
	_apply()
	if rise > 0.3:
		for b in get_overlapping_bodies():
			if b.is_in_group("player"):
				if b.star_t > 0.0:
					die_fire()
				else:
					b.hurt()


func die_fire() -> void:
	if dead:
		return
	dead = true
	Audio.play("kick")
	level.add_score(200, global_position + Vector2(0, -24))
	level.burst(global_position + Vector2(0, -12), Color(0.9, 0.2, 0.2), 8, 60.0)
	queue_free()
