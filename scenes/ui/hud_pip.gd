class_name HudPip
extends Control
## HudPip — one dreamling pip in the HUD's counter row (D12: dense
## collectibles shown as pips + one numeral, never a bare fraction). A
## small drawn circle — no texture assets exist for this yet, and a circle
## needs none. Three read states: dim dusk-blue = untouched, hollow gold
## ring = collected-but-carried, filled gold = returned home.
##
## paint() sets the look with no animation (used once, at world-load, so
## the whole row doesn't pop at once). animate_to() is the live-update
## path: repaint + a gentle scale pop (1.0 -> 1.25 -> 1.0 over ~0.3 s) so a
## change is felt, not just seen — never a flash, per the design floor.

enum PipState { UNTOUCHED, CARRIED, RETURNED }

const DIAMETER: float = 18.0
const RADIUS: float = DIAMETER * 0.5
const RING_WIDTH: float = 2.5
const POP_SCALE: float = 1.25
const POP_HALF_DURATION: float = 0.15

const COLOR_RETURNED: Color = Color(1.0, 0.952941, 0.768627, 1.0) # FFF3C4 dreamling gold
const COLOR_UNTOUCHED: Color = Color(0.180392, 0.231373, 0.368627, 0.5) # dusk blue, dim

var state: PipState = PipState.UNTOUCHED

var _tween: Tween = null


func _ready() -> void:
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	pivot_offset = custom_minimum_size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## paint — set the look with no animation (initial world-load state).
func paint(new_state: PipState) -> void:
	state = new_state
	queue_redraw()


## animate_to — live state change: repaints AND pops.
func animate_to(new_state: PipState) -> void:
	state = new_state
	queue_redraw()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	scale = Vector2.ONE
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * POP_SCALE, POP_HALF_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, POP_HALF_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	match state:
		PipState.RETURNED:
			draw_circle(center, RADIUS, COLOR_RETURNED)
		PipState.CARRIED:
			draw_arc(center, RADIUS - RING_WIDTH * 0.5, 0.0, TAU, 32, COLOR_RETURNED, RING_WIDTH, true)
		PipState.UNTOUCHED:
			draw_circle(center, RADIUS, COLOR_UNTOUCHED)
