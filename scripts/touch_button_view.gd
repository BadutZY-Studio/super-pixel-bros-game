extends Control
## One round on-screen button (pixel-art style). Used by the in-game overlay (touch_controls.gd)
## and by the layout editor (touch_editor.gd).

var id := ""
var pressed := false
var selected := false     # editor: gold ring around the button being edited
var ghost := false        # editor: button is switched off, shown faded

const INK := Color(0.04, 0.04, 0.12)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Re-reads position / size / opacity from the saved layout.
func refresh() -> void:
	var r: float = TouchUI.radius(id)
	var d: float = ceilf(r) * 2.0 + 12.0
	size = Vector2(d, d)
	position = (TouchUI.center(id).round() - size * 0.5).round()
	var a: float = TouchUI.alpha(id)
	visible = TouchUI.is_on(id) or ghost
	modulate.a = a if not ghost else maxf(a * 0.45, 0.25)
	queue_redraw()


func _disc(c: Vector2, r: float, col: Color) -> void:
	var cx := roundf(c.x)
	var cy := roundf(c.y)
	var ri := int(ceilf(r))
	for dy in range(-ri, ri):
		var yy := float(dy) + 0.5
		var half := floorf(sqrt(maxf(r * r - yy * yy, 0.0)))
		if half > 0.0:
			draw_rect(Rect2(cx - half, cy + float(dy), half * 2.0, 1.0), col)


## Triangle made of 1px columns / rows. dir: 0 = left, 1 = right, 2 = up, 3 = down
func _tri(c: Vector2, s: float, dir: int, col: Color) -> void:
	var n := int(roundf(s))
	for i in range(n + 1):
		var half := float(i) * 0.95
		match dir:
			0:
				draw_rect(Rect2(roundf(c.x - s * 0.5) + float(i), roundf(c.y - half), 1.0, roundf(half) * 2.0 + 1.0), col)
			1:
				draw_rect(Rect2(roundf(c.x + s * 0.5) - float(i) - 1.0, roundf(c.y - half), 1.0, roundf(half) * 2.0 + 1.0), col)
			2:
				draw_rect(Rect2(roundf(c.x - half), roundf(c.y - s * 0.5) + float(i), roundf(half) * 2.0 + 1.0, 1.0), col)
			3:
				draw_rect(Rect2(roundf(c.x - half), roundf(c.y + s * 0.5) - float(i) - 1.0, roundf(half) * 2.0 + 1.0, 1.0), col)


func _glyph(c: Vector2, r: float, col: Color) -> void:
	var s := maxf(r * 0.55, 4.0)
	match id:
		"left":
			_tri(c, s, 0, col)
		"right":
			_tri(c, s, 1, col)
		"down":
			_tri(c, s, 3, col)
		"jump":
			_tri(c + Vector2(0, -s * 0.15), s, 2, col)
			draw_rect(Rect2(roundf(c.x - s * 0.22), roundf(c.y + s * 0.05), maxf(roundf(s * 0.44), 2.0), roundf(s * 0.5)), col)
		"run":
			var h := s * 0.75
			_tri(c + Vector2(-h * 0.45, 0), h, 1, col)
			_tri(c + Vector2(h * 0.55, 0), h, 1, col)
		"fire":
			_disc(c + Vector2(0, 1), s * 0.62, col)
			_disc(c + Vector2(0, 2), s * 0.28, Color(1.0, 0.85, 0.2) if col.r > 0.9 else col.darkened(0.4))
		"pause":
			var w := maxf(roundf(s * 0.28), 2.0)
			var hh := roundf(s * 0.9)
			draw_rect(Rect2(roundf(c.x - s * 0.45), roundf(c.y - hh * 0.5), w, hh), col)
			draw_rect(Rect2(roundf(c.x + s * 0.45 - w), roundf(c.y - hh * 0.5), w, hh), col)


func _draw() -> void:
	if id == "":
		return
	var c := size * 0.5
	var r: float = TouchUI.radius(id)
	var base: Color = TouchUI.DEFS[id]["color"]
	var lift := Vector2(0, 1) if pressed else Vector2.ZERO
	if selected:
		_disc(c, r + 4.0, Color(1.0, 0.82, 0.2))
		_disc(c, r + 2.0, INK)
	_disc(c + Vector2(0, 2), r, Color(0, 0, 0, 0.45))
	_disc(c + lift, r, INK)
	_disc(c + lift, r - 1.5, base.darkened(0.5))
	var face := base.lightened(0.35) if pressed else base
	_disc(c + lift + Vector2(0, -1), r - 3.0, face)
	_disc(c + lift + Vector2(0, -2.5), r - 6.0, face.lightened(0.18))
	_glyph(c + lift + Vector2(0, 1), r, Color(0, 0, 0, 0.45))
	_glyph(c + lift, r, Color.WHITE)
