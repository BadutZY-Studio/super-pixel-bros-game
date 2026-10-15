extends CharacterBody2D
## Coin / mushroom / fire flower / coin_pop (block reward). Origin = centre of sprite.

var kind := "coin"
var level
var emerge := false
var dir := 1
var sprite: AnimatedSprite2D
var area: Area2D
var taken := false
var moving := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	sprite = AnimatedSprite2D.new()
	add_child(sprite)
	var coin_frames := Game.make_frames(Game.tex("res://assets/sprites/coin.png"), 16, 16, {
		"spin": {"frames": [0, 1, 2, 3], "fps": 9, "loop": true}})
	match kind:
		"coin":
			sprite.sprite_frames = coin_frames
			sprite.play("spin")
			sprite.frame = randi() % 4
			set_physics_process(false)
		"coin_pop":
			sprite.sprite_frames = coin_frames
			sprite.speed_scale = 2.5
			sprite.play("spin")
			set_physics_process(false)
			z_index = -1
			var tw := create_tween()
			tw.tween_property(self, "position:y", position.y - 44.0, 0.28).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "position:y", position.y - 26.0, 0.22).set_ease(Tween.EASE_IN)
			tw.tween_callback(queue_free)
			return
		"mushroom":
			sprite.sprite_frames = Game.make_frames(Game.tex("res://assets/sprites/mushroom.png"), 16, 16, {
				"idle": {"frames": [0], "fps": 1, "loop": true}})
			sprite.play("idle")
		"flower":
			sprite.sprite_frames = Game.make_frames(Game.tex("res://assets/sprites/flower.png"), 16, 16, {
				"idle": {"frames": [0], "fps": 1, "loop": true}})
			sprite.play("idle")
		"star":
			sprite.sprite_frames = Game.make_frames(Game.tex("res://assets/sprites/star.png"), 16, 16, {
				"spin": {"frames": [0, 1], "fps": 8, "loop": true}})
			sprite.play("spin")
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(12, 14) if kind != "coin" else Vector2(10, 12)
	cs.shape = rs
	add_child(cs)
	cs.disabled = kind == "coin"
	area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var acs := CollisionShape2D.new()
	var ars := RectangleShape2D.new()
	ars.size = Vector2(12, 14) if kind != "coin" else Vector2(12, 14)
	acs.shape = ars
	area.add_child(acs)
	add_child(area)
	area.body_entered.connect(_on_body)
	if emerge:
		z_index = -1
		area.monitoring = false
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_property(self, "position:y", position.y - 16.0, 0.55)
		tw.tween_callback(_emerged)
	elif kind != "coin":
		moving = true


func _emerged() -> void:
	z_index = 0
	area.monitoring = true
	moving = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not moving:
		return
	if kind == "mushroom" or kind == "star":
		velocity.x = dir * (45.0 if kind == "mushroom" else 62.0)
		velocity.y = minf(velocity.y + 900.0 * delta, 300.0)
		move_and_slide()
		if kind == "star" and is_on_floor():
			velocity.y = -230.0
		if is_on_wall():
			dir = -dir
		if global_position.y > 270.0:
			queue_free()
	else:
		set_physics_process(false)


func _on_body(b: Node) -> void:
	if taken or not b.is_in_group("player") or b.dead:
		return
	taken = true
	match kind:
		"coin":
			level.collect_coin(global_position)
		"mushroom", "flower", "star":
			b.powerup(kind)
	queue_free()
