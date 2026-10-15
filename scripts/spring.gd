extends Area2D
## Spring pad (chapter 2). Land on it (or walk over it) and it launches you very high.
## Hold JUMP while it fires to rise to the full height. Origin = bottom centre of the sprite.

const POWER := -545.0

var level
var sprite: AnimatedSprite2D
var cooldown := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Game.make_frames(Game.tex("res://assets/sprites/spring.png"), 16, 16, {
		"rest": {"frames": [0], "fps": 1, "loop": true},
		"squash": {"frames": [1], "fps": 1, "loop": true},
		"up": {"frames": [2], "fps": 1, "loop": true}})
	sprite.offset = Vector2(0, -8)
	sprite.play("rest")
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(12, 7)
	cs.shape = rs
	cs.position = Vector2(0, -3.5)
	add_child(cs)


func _physics_process(delta: float) -> void:
	if cooldown > 0.0:
		cooldown -= delta
		return
	for b in get_overlapping_bodies():
		if b.is_in_group("player") and not b.dead and b.velocity.y >= 0.0:
			cooldown = 0.3
			b.spring_launch(POWER)
			Audio.play("jump_big", 1.5)
			sprite.play("up")
			get_tree().create_timer(0.35).timeout.connect(func():
				if is_instance_valid(sprite):
					sprite.play("rest"))
			return
