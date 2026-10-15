extends StaticBody2D
## Breakable brick / question block. Origin = block centre.

var level
var kind := "brick"       # brick | q | used
var content := "coin"     # coin | powerup
var sprite: Sprite2D
var atlas: AtlasTexture
var busy := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(16, 16)
	cs.shape = rs
	add_child(cs)
	atlas = AtlasTexture.new()
	atlas.atlas = level.tile_tex
	sprite = Sprite2D.new()
	sprite.texture = atlas
	add_child(sprite)
	_set_idx(2 if kind == "brick" else 11)


func _set_idx(i: int) -> void:
	atlas.region = Rect2(i * 16, 0, 16, 16)


func _process(_delta: float) -> void:
	if kind == "q":
		_set_idx(11 + (Time.get_ticks_msec() / 140) % 3)


func _hop() -> void:
	busy = true
	level.kill_on_top(global_position)
	var tw := create_tween()
	tw.tween_property(sprite, "position:y", -5.0, 0.07)
	tw.tween_property(sprite, "position:y", 0.0, 0.09)
	tw.tween_callback(func(): busy = false)


func bump(p) -> void:
	if busy:
		return
	match kind:
		"brick":
			if p.state > 0:
				_break()
			else:
				_hop()
				Audio.play("bump")
		"q":
			kind = "used"
			_set_idx(4)
			_hop()
			if content == "coin":
				Audio.play("coin")
				level.spawn_coin_pop(global_position)
			elif content == "star":
				Audio.play("powerup_appear")
				level.spawn_star(global_position)
			else:
				Audio.play("powerup_appear")
				level.spawn_powerup(global_position, p.state)
		_:
			_hop()
			Audio.play("bump")


func _break() -> void:
	Audio.play("break")
	level.kill_on_top(global_position)
	level.add_score(50, global_position + Vector2(0, -12))
	level.debris(global_position, level.tile_tex)
	queue_free()
