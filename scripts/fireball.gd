extends CharacterBody2D

var dir := 1
var owner_player
var level
var sprite: AnimatedSprite2D
var area: Area2D
var _freed := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Game.make_frames(Game.tex("res://assets/sprites/fireball.png"), 8, 8, {
		"spin": {"frames": [0, 1], "fps": 14, "loop": true}})
	sprite.play("spin")
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 3.0
	cs.shape = circ
	add_child(cs)
	area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 4
	var acs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(8, 8)
	acs.shape = rs
	area.add_child(acs)
	add_child(area)
	area.body_entered.connect(_on_body)
	area.area_entered.connect(_on_area)
	velocity = Vector2(dir * 180.0, 60.0)


func _physics_process(delta: float) -> void:
	velocity.y += 900.0 * delta
	velocity.x = dir * 180.0
	move_and_slide()
	if is_on_floor():
		velocity.y = -190.0
	if is_on_wall():
		_explode()
		return
	if absf(global_position.x - level.cam_x) > 230.0 or global_position.y > 260.0:
		_release()


func _on_body(b: Node) -> void:
	if b.is_in_group("enemies") and b.state != "dead":
		b.die_flip(true)
		_explode()


func _on_area(a: Area2D) -> void:
	if a.has_method("die_fire"):
		a.die_fire()
		_explode()


func _explode() -> void:
	if _freed:
		return
	Audio.play("bump", 1.6)
	level.burst(global_position, Color(1.0, 0.6, 0.2), 6, 50.0)
	_release()


func _release() -> void:
	if _freed:
		return
	_freed = true
	if is_instance_valid(owner_player):
		owner_player.fireballs = maxi(0, owner_player.fireballs - 1)
	queue_free()
