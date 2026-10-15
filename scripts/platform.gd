extends AnimatableBody2D
## Moving one-way platform.

var horizontal := true
var range_px := 48.0
var speed := 1.2
var origin := Vector2.ZERO
var t := 0.0


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(46, 6)
	cs.shape = rs
	cs.one_way_collision = true
	cs.position = Vector2(0, -1)
	add_child(cs)
	var sp := Sprite2D.new()
	sp.texture = Game.tex("res://assets/sprites/platform.png")
	sp.position = Vector2(0, 1)
	add_child(sp)
	origin = position
	t = randf() * 0.0


func _physics_process(delta: float) -> void:
	t += delta * speed
	var o := sin(t) * range_px
	position = origin + (Vector2(o, 0) if horizontal else Vector2(0, o))
