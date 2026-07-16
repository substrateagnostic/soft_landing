class_name DuskGradient
extends Control
## DuskGradient — full-rect vertical dusk-to-rose sky gradient
## (ART_BIBLE.md "Sky (zenith)" / "Sky (horizon)"), drawn via a
## per-vertex-colored quad — draw_polygon interpolates the two colors
## across the rect for us, so no gradient texture/resource is needed.
## Used as the title screen's background.

const COLOR_TOP: Color = Color(0.180392, 0.231373, 0.368627, 1.0) # deep dusk blue
const COLOR_BOTTOM: Color = Color(0.85098, 0.647059, 0.701961, 1.0) # rose quartz


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(size.x, 0.0), Vector2(size.x, size.y), Vector2(0.0, size.y),
	])
	var colors: PackedColorArray = PackedColorArray([COLOR_TOP, COLOR_TOP, COLOR_BOTTOM, COLOR_BOTTOM])
	draw_polygon(points, colors)
