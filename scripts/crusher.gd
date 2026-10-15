extends Area2D
## Spiked stone (chapter 2): hangs in the air, shakes when you walk underneath, then slams to the floor.
## It rises back up slowly afterwards. Touching it hurts. Origin = centre of the 24x24 block.

const FLOOR_Y := 192.0

var level
var state := "idle"       # idle | shake | slam | rest | rise
var home := Vector2.ZERO
var timer := 0.0
var vy := 0.0
var sprite: AnimatedSprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 1
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Game.make_frames(Game.tex("res://assets/sprites/crusher.png"), 24, 24, {
		"calm": {"frames": [0], "fps": 1, "loop": true},
		"angry": {"frames": [1], "fps": 1, "loop": true}})
	sprite.play("calm")
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(20, 22)
	cs.shape = rs
	add_child(cs)
	home = position


func _physics_process(delta: float) -> void:
	if absf(global_position.x - level.cam_x) > 260.0:
		return
	var p = level.player
	match state:
		"idle":
			if p != null and not p.dead and absf(p.global_position.x - global_position.x) < 22.0 and p.global_position.y > global_position.y:
				state = "shake"
				timer = 0.3
				sprite.play("angry")
		"shake":
			sprite.position.x = float(int(Time.get_ticks_msec() / 40) % 2) * 2.0 - 1.0
			timer -= delta
			if timer <= 0.0:
				sprite.position.x = 0.0
				state = "slam"
				vy = 0.0
		"slam":
			vy = minf(vy + 1500.0 * delta, 500.0)
			position.y += vy * delta
			if position.y >= FLOOR_Y - 12.0:
				position.y = FLOOR_Y - 12.0
				state = "rest"
				timer = 0.85
				Audio.play("bump", 0.6)
				level.burst(Vector2(global_position.x, FLOOR_Y), Color(0.8, 0.8, 0.9), 8, 70.0)
		"rest":
			timer -= delta
			if timer <= 0.0:
				state = "rise"
				sprite.play("calm")
		"rise":
			position.y = move_toward(position.y, home.y, 60.0 * delta)
			if absf(position.y - home.y) < 0.5:
				position.y = home.y
				state = "idle"
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			b.hurt()
