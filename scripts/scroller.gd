extends Node2D
## Horizontally tiling parallax strip (used by menus and level backgrounds).

var tex: Texture2D
var factor := 1.0
var auto_speed := 0.0
var scroll := 0.0
var sprites: Array = []


func setup(t: Texture2D, f: float, bottom: float, auto: float = 0.0, tint: Color = Color.WHITE) -> void:
	tex = t
	factor = f
	auto_speed = auto
	var w := t.get_width()
	var n := int(ceil(400.0 / w)) + 2
	for i in n:
		var s := Sprite2D.new()
		s.texture = t
		s.centered = false
		s.modulate = tint
		s.position.y = bottom - t.get_height()
		add_child(s)
		sprites.append(s)
	_update()


func _process(delta: float) -> void:
	scroll += auto_speed * delta
	_update()


func _update() -> void:
	if tex == null:
		return
	var w := float(tex.get_width())
	var off := fposmod(scroll * factor, w)
	for i in sprites.size():
		sprites[i].position.x = roundf(-off + i * w)
