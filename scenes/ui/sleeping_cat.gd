class_name SleepingCat
extends Control
## SleepingCat — a settled, breathing cat silhouette accent for the title
## screen (title screen v2, D20 UI pass) — a Callie touch. Purely
## decorative: no click/interact target, no game-state read. Procedural
## silhouette (ellipse body, two triangle ears, a curled tail arc) since
## no cat sprite asset exists yet — same "draw it" convention as the
## title screen's other new accents. Draws around a fixed local point
## rather than depending on the host Control's assigned rect size.

const COLOR: Color = Color(0.180392, 0.231373, 0.368627, 0.55) # dusk blue silhouette
const BODY_SIZE: Vector2 = Vector2(96.0, 46.0)
const BREATHE_PERIOD: float = 4.2
const BREATHE_SCALE: float = 1.035

const LOCAL_BASE: Vector2 = Vector2(BODY_SIZE.x * 0.65, BODY_SIZE.y * 1.7)

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = LOCAL_BASE


func _process(delta: float) -> void:
	_time += delta
	var t: float = _time * TAU / BREATHE_PERIOD
	var s: float = 1.0 + (BREATHE_SCALE - 1.0) * 0.5 * (1.0 - cos(t))
	scale = Vector2(1.0, s) # breathing reads on the body's height, not width
	queue_redraw()


func _draw() -> void:
	# curled tail: a thick arc wrapping the body's right side
	draw_arc(
		LOCAL_BASE + Vector2(BODY_SIZE.x * 0.28, -BODY_SIZE.y * 0.65), BODY_SIZE.x * 0.32,
		-0.3, PI * 1.15, 24, COLOR, 9.0, true
	)
	# body: a squashed ellipse (curled, sleeping shape)
	draw_colored_polygon(_ellipse_points(LOCAL_BASE - Vector2(0.0, BODY_SIZE.y * 0.5), BODY_SIZE * 0.5, 28), COLOR)
	# two small ears
	var ear_base: Vector2 = LOCAL_BASE - Vector2(BODY_SIZE.x * 0.28, BODY_SIZE.y * 0.92)
	_draw_ear(ear_base)
	_draw_ear(ear_base + Vector2(BODY_SIZE.x * 0.16, 0.0))


func _draw_ear(tip_base: Vector2) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		tip_base + Vector2(-6.0, 10.0),
		tip_base + Vector2(6.0, 10.0),
		tip_base + Vector2(0.0, -10.0),
	])
	draw_colored_polygon(points, COLOR)


func _ellipse_points(center: Vector2, radii: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var a: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points
