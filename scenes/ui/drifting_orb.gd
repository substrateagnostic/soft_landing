class_name DriftingOrb
extends Control
## DriftingOrb — one of the title screen's three tiny gold orbs. Draws
## itself (a soft dreamling-gold circle) and drifts continuously via sine
## offsets from its own anchored base position — no Tween bookkeeping, no
## restart seams, just a smooth endless float (ART_BIBLE.md "Animation":
## the whole game breathes).

const COLOR: Color = Color(1.0, 0.952941, 0.768627, 0.85) # FFF3C4 dreamling gold
const RADIUS: float = 6.0

@export var drift_amplitude: Vector2 = Vector2(10.0, 16.0)
@export var drift_period: float = 6.0
@export var phase: float = 0.0

var _base_position: Vector2 = Vector2.ZERO
var _time: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_position = position
	_time = phase


func _process(delta: float) -> void:
	_time += delta
	var t: float = _time * TAU / drift_period
	position = _base_position + Vector2(sin(t) * drift_amplitude.x, sin(t * 0.6) * drift_amplitude.y)


func _draw() -> void:
	draw_circle(Vector2(RADIUS, RADIUS), RADIUS, COLOR)
