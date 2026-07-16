class_name IconDraw
extends Control
## IconDraw — tiny procedural pause-menu icon (no icon/texture assets exist
## for this project — ART_BIBLE.md's "Meshy makes vs engine makes" list
## doesn't cover 2D UI glyphs either, so these are drawn, not imported).
## PLAY (Keep Playing) and MOON (Sleep) are the original pause-row pair.
## The rest (GEAR/BACK/MUSIC/SPEAKER/CAMERA/VOICE_NOTES/VOICE_MOUTH/
## VOICE_TEXT) were added for the pause options subpanel (D20 UI pass,
## Xbox Accessibility Guidelines' icon-consistency rule per
## docs/research/v2/ui_writing.md §2 — every one of these is paired with a
## short label in pause_menu.gd, never icon-only). Sizing/position are the
## caller's job (pause_menu.gd sets icon_size + manual center offsets
## after construction); this script only draws.

enum Kind {
	PLAY, MOON, GEAR, BACK, MUSIC, SPEAKER, CAMERA,
	VOICE_NOTES, VOICE_MOUTH, VOICE_TEXT,
}

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
		Kind.GEAR:
			_draw_gear(center, r)
		Kind.BACK:
			_draw_back(center, r)
		Kind.MUSIC:
			_draw_music(center, r)
		Kind.SPEAKER:
			_draw_speaker(center, r)
		Kind.CAMERA:
			_draw_camera(center, r)
		Kind.VOICE_NOTES:
			_draw_moon(center, r * 0.72)
			_draw_music(center + Vector2(r * 0.55, r * 0.4), r * 0.42)
		Kind.VOICE_MOUTH:
			_draw_moon(center, r * 0.72)
			_draw_mouth(center + Vector2(r * 0.5, r * 0.5), r * 0.4)
		Kind.VOICE_TEXT:
			_draw_text_lines(center, r)


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


## _draw_gear — a ring with six blunt teeth (small rects rotated around
## the center) plus a cutout hub, read as "options" at a glance without
## needing to resemble a specific real-world cog too literally.
func _draw_gear(center: Vector2, r: float) -> void:
	draw_arc(center, r * 0.72, 0.0, TAU, 32, icon_color, r * 0.34, true)
	var tooth_count: int = 6
	for i: int in range(tooth_count):
		var angle: float = TAU * float(i) / float(tooth_count)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var inner: Vector2 = center + dir * r * 0.82
		var outer: Vector2 = center + dir * r
		var half_w: Vector2 = perp * r * 0.14
		draw_colored_polygon(PackedVector2Array([
			inner - half_w, inner + half_w, outer + half_w, outer - half_w,
		]), icon_color)
	draw_circle(center, r * 0.26, cutout_color)


## _draw_back — a simple left-pointing chevron (returns from the options
## subpanel to the main pause row).
func _draw_back(center: Vector2, r: float) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(r * 0.55, -r * 0.75),
		center + Vector2(-r * 0.55, 0.0),
		center + Vector2(r * 0.55, r * 0.75),
	])
	for i: int in range(points.size() - 1):
		draw_line(points[i], points[i + 1], icon_color, r * 0.3, true)


## _draw_music — a single filled notehead + stem + flag (the "music" side
## of the volume sliders, and the badge on VOICE_NOTES).
func _draw_music(center: Vector2, r: float) -> void:
	var head: Vector2 = center + Vector2(-r * 0.25, r * 0.55)
	draw_circle(head, r * 0.32, icon_color)
	var stem_top: Vector2 = head + Vector2(r * 0.3, -r * 1.15)
	draw_line(head + Vector2(r * 0.3, 0.0), stem_top, icon_color, r * 0.14, true)
	draw_colored_polygon(PackedVector2Array([
		stem_top,
		stem_top + Vector2(r * 0.5, r * 0.18),
		stem_top + Vector2(r * 0.42, r * 0.55),
	]), icon_color)


## _draw_speaker — a small trapezoid cone + two soft arcs (sound waves).
func _draw_speaker(center: Vector2, r: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-r * 0.85, -r * 0.32),
		center + Vector2(-r * 0.3, -r * 0.32),
		center + Vector2(r * 0.15, -r * 0.75),
		center + Vector2(r * 0.15, r * 0.75),
		center + Vector2(-r * 0.3, r * 0.32),
		center + Vector2(-r * 0.85, r * 0.32),
	]), icon_color)
	draw_arc(center + Vector2(r * 0.15, 0.0), r * 0.55, -0.7, 0.7, 16, icon_color, r * 0.12, true)
	draw_arc(center + Vector2(r * 0.15, 0.0), r * 0.95, -0.6, 0.6, 16, icon_color, r * 0.12, true)


## _draw_camera — a rounded body + a lens circle + a small viewfinder bump.
func _draw_camera(center: Vector2, r: float) -> void:
	var body_rect := Rect2(center + Vector2(-r * 0.95, -r * 0.55), Vector2(r * 1.9, r * 1.1))
	draw_rect(body_rect, icon_color, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-r * 0.3, -r * 0.55),
		center + Vector2(r * 0.0, -r * 0.85),
		center + Vector2(r * 0.35, -r * 0.85),
		center + Vector2(r * 0.35, -r * 0.55),
	]), icon_color)
	draw_circle(center + Vector2(0.0, r * 0.05), r * 0.4, cutout_color)
	draw_circle(center + Vector2(0.0, r * 0.05), r * 0.26, icon_color)


## _draw_mouth — a small open-mouth arc (the "speaks aloud" badge on
## VOICE_MOUTH, paired with a smaller moon so the pairing reads as
## "moon + spoken words").
func _draw_mouth(center: Vector2, r: float) -> void:
	draw_arc(center, r * 0.6, 0.15 * PI, 0.85 * PI, 16, icon_color, r * 0.3, true)


## _draw_text_lines — three horizontal bars of decreasing width, standing
## in for "words on screen" without needing legible glyph rendering at
## icon scale.
func _draw_text_lines(center: Vector2, r: float) -> void:
	var widths: Array[float] = [1.5, 1.15, 0.75]
	var y: float = -r * 0.6
	for w: float in widths:
		draw_line(
			center + Vector2(-r * 0.5 * w, y), center + Vector2(r * 0.5 * w, y),
			icon_color, r * 0.24, true
		)
		y += r * 0.6
