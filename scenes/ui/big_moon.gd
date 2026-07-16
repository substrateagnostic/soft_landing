class_name BigMoon
extends Control
## BigMoon — the title sky's big pale moon (title screen v2, D20 UI pass).
## A soft-edged circle (concentric falling-alpha rings stand in for a
## glow — same "no texture assets, draw it" convention as IconDraw/
## DriftingOrb/DuskGradient) that breathes very slightly on its own
## period, independent of the title text's breathing. Draws around a
## fixed local point rather than `size * 0.5` so it doesn't care how its
## host Control's rect is sized in the scene — only where its top-left
## corner is anchored.

const COLOR_CORE: Color = Color(0.988235, 0.976471, 0.882353, 1.0) # pale moon cream
const SHADOW_COLOR: Color = Color(0.180392, 0.231373, 0.368627, 0.16) # dusk blue, soft overlay
const RADIUS: float = 70.0
const GLOW_RINGS: int = 4
const GLOW_SPREAD: float = 1.9
const BREATHE_PERIOD: float = 7.0
const BREATHE_SCALE: float = 1.04

const LOCAL_CENTER: Vector2 = Vector2(RADIUS * GLOW_SPREAD, RADIUS * GLOW_SPREAD)

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = LOCAL_CENTER


func _process(delta: float) -> void:
	_time += delta
	var t: float = _time * TAU / BREATHE_PERIOD
	var s: float = 1.0 + (BREATHE_SCALE - 1.0) * 0.5 * (1.0 - cos(t))
	scale = Vector2.ONE * s
	queue_redraw()


func _draw() -> void:
	for i in range(GLOW_RINGS, 0, -1):
		var t: float = float(i) / float(GLOW_RINGS)
		var r: float = RADIUS * (1.0 + (GLOW_SPREAD - 1.0) * t)
		var alpha: float = 0.10 * (1.0 - t)
		draw_circle(LOCAL_CENTER, r, Color(COLOR_CORE.r, COLOR_CORE.g, COLOR_CORE.b, alpha))
	draw_circle(LOCAL_CENTER, RADIUS, COLOR_CORE)
	# a soft crescent shadow — a translucent overlay (not a bg-color cutout,
	# since the sky behind this is a gradient, not a flat color) tinting one
	# side so the moon doesn't read as a flat coin.
	draw_circle(LOCAL_CENTER + Vector2(RADIUS * 0.32, -RADIUS * 0.12), RADIUS * 0.88, SHADOW_COLOR)
