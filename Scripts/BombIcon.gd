extends Control

## Draws a bomb-type symbol: horizontal line (Row), vertical line (Column), or X (Diagonal).

var bomb_type: int = 0
var icon_color: Color = Color.WHITE


func _draw():
	var m = 3.0
	var w = size.x
	var h = size.y
	var thickness = 3.0

	match bomb_type:
		0: # ROW — horizontal line
			draw_line(Vector2(m, h / 2), Vector2(w - m, h / 2), icon_color, thickness, true)
		1: # COLUMN — vertical line
			draw_line(Vector2(w / 2, m), Vector2(w / 2, h - m), icon_color, thickness, true)
		2: # DIAGONAL — X shape
			draw_line(Vector2(m, m), Vector2(w - m, h - m), icon_color, thickness, true)
			draw_line(Vector2(w - m, m), Vector2(m, h - m), icon_color, thickness, true)
