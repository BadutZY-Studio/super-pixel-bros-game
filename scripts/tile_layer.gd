extends Node2D
## Draws all static tiles in one go.

var tex: Texture2D
var cells: Array = []   # [col, row, tile_index]


func _draw() -> void:
	for c in cells:
		draw_texture_rect_region(tex, Rect2(c[0] * 16, c[1] * 16, 16, 16), Rect2(c[2] * 16, 0, 16, 16))
