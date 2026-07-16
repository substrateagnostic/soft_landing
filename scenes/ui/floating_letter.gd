class_name FloatingLetter
extends Label
## FloatingLetter — one character of the title screen's heading, bobbing
## independently on a sine offset from its own laid-out position (title
## screen v2, D20 UI pass — docs/research/v2/ui_writing.md Actionable #11:
## "a subtle idle-interaction layer... signals this is a game about gentle
## presence before any menu item is even selected"). Same technique as
## DriftingOrb (offset from a captured base position, no per-letter Tween
## bookkeeping) so a whole word of these costs nothing extra to animate.
## The base position is captured lazily on the first `_process` tick
## rather than in `_ready()`, because the parent HBoxContainer hasn't laid
## this label out yet at `_ready()` time — capturing too early would bob
## around (0,0) for one frame, then visibly snap.

const BOB_AMPLITUDE: float = 5.0
@export var bob_period: float = 2.4
@export var phase: float = 0.0

var _base_position: Vector2 = Vector2.ZERO
var _base_captured: bool = false
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time = phase


func _process(delta: float) -> void:
	if not _base_captured:
		_base_position = position
		_base_captured = true
	_time += delta
	position = _base_position + Vector2(0.0, sin(_time * TAU / bob_period) * BOB_AMPLITUDE)
