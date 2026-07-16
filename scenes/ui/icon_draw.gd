class_name IconDraw
extends Control
## IconDraw — tiny procedural pause-menu icon (no icon/texture assets exist
## for this project — ART_BIBLE.md's "Meshy makes vs engine makes" list
## doesn't cover 2D UI glyphs either, so these are drawn, not imported).
## Two kinds: PLAY (a soft triangle — Keep Playing) and MOON (a crescent,
## carved from a plain circle by overdrawing a circle in the button's own
## background color — Sleep). Sizing/position are the caller's job
## (pause_menu.gd sets icon_size + manual center offsets after
## construction); this script only draws.

enum Kind { PLAY, MOON }

@export var kind: Kind = Kind.PLAY
@export var icon_color: Color = Color(0.960784, 0.94902, 0.909804, 1.0) # milk white
@export var cutout_color: Color = Color(0.180392, 0.231373, 0.368627, 1.0) # matches button bg
@export var icon_size: float = 44.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var r: float = min(size.x, size.y) * 0.5
	match kind:
		Kind.PLAY:
			_draw_play(center, r)
		Kind.MOON:
			_draw_moon(center, r)


func _draw_play(center: Vector2, r: float) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(-r * 0.7, -r),
		center + Vector2(-r * 0.7, r),
		center + Vector2(r, 0.0),
	])
	draw_colored_polygon(points, icon_color)
	for point: Vector2 in points: # soften the three corners a touch
		draw_circle(point, r * 0.14, icon_color)


func _draw_moon(center: Vector2, r: float) -> void:
	draw_circle(center, r, icon_color)
	draw_circle(center + Vector2(r * 0.5, -r * 0.18), r * 0.82, cutout_color)
