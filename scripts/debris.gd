extends Sprite2D

var vel := Vector2.ZERO


func _process(delta: float) -> void:
	vel.y += 800.0 * delta
	position += vel * delta
	rotation += vel.x * 0.04 * delta
	if position.y > 330.0:
		queue_free()
