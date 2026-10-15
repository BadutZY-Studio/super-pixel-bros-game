extends AnimatableBody2D
## Platform that shakes and drops a moment after you step on it, then comes back (chapter 2).

var origin := Vector2.ZERO
var state := "idle"       # idle | shake | fall | gone
var timer := 0.0
var vy := 0.0
var sprite: Sprite2D
var shape_node: CollisionShape2D
var trigger: Area2D


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	shape_node = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(46, 6)
	shape_node.shape = rs
	shape_node.one_way_collision = true
	shape_node.position = Vector2(0, -1)
	add_child(shape_node)
	sprite = Sprite2D.new()
	sprite.texture = Game.tex("res://assets/sprites/platform.png")
	sprite.position = Vector2(0, 1)
	sprite.modulate = Color(1.0, 0.72, 0.62)
	add_child(sprite)
	trigger = Area2D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	var ts := CollisionShape2D.new()
	var tr := RectangleShape2D.new()
	tr.size = Vector2(42, 6)
	ts.shape = tr
	ts.position = Vector2(0, -4)
	trigger.add_child(ts)
	add_child(trigger)
	origin = position


func _physics_process(delta: float) -> void:
	match state:
		"idle":
			for b in trigger.get_overlapping_bodies():
				if b.is_in_group("player") and not b.dead:
					state = "shake"
					timer = 0.45
					break
		"shake":
			sprite.position = Vector2(float(int(Time.get_ticks_msec() / 45) % 2) * 2.0 - 1.0, 1.0)
			timer -= delta
			if timer <= 0.0:
				sprite.position = Vector2(0, 1)
				state = "fall"
				vy = 0.0
		"fall":
			vy = minf(vy + 520.0 * delta, 420.0)
			position.y += vy * delta
			if position.y > 290.0:
				state = "gone"
				timer = 2.6
				visible = false
				shape_node.set_deferred("disabled", true)
		"gone":
			timer -= delta
			if timer <= 0.0:
				position = origin
				visible = true
				shape_node.set_deferred("disabled", false)
				state = "idle"
