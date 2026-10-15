extends Node2D
## Rotating bar of fireballs around a hard block (chapter 2). Origin = centre of the block.

const BALLS := 5
const STEP := 7.0

var level
var ang := 0.0
var speed := 1.7
var balls: Array = []


func _ready() -> void:
	z_index = 1
	var frames := Game.make_frames(Game.tex("res://assets/sprites/fireball.png"), 8, 8, {
		"spin": {"frames": [0, 1], "fps": 10, "loop": true}})
	for i in BALLS:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = frames
		s.play("spin")
		s.frame = i % 2
		add_child(s)
		balls.append(s)
	ang = level.rng.randf() * TAU
	if level.rng.randf() < 0.5:
		speed = -speed
	_place()


func _place() -> void:
	for i in balls.size():
		(balls[i] as Node2D).position = Vector2(cos(ang), sin(ang)) * STEP * float(i + 1)


func _physics_process(delta: float) -> void:
	ang += speed * delta
	_place()
	if absf(global_position.x - level.cam_x) > 260.0:
		return
	var p = level.player
	if p == null or p.dead:
		return
	var h: float = 16.0 if p.state == 0 else 32.0
	for i in BALLS:
		var bp: Vector2 = global_position + Vector2(cos(ang), sin(ang)) * STEP * float(i + 1)
		if absf(bp.x - p.global_position.x) < 8.0 and bp.y > p.global_position.y - h - 2.0 and bp.y < p.global_position.y + 2.0:
			p.hurt()
			return
