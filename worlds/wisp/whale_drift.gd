class_name WhaleDrift
extends AnimatableBody3D
## WhaleDrift — Wisp's whole-body vertical breath (world-card wisp.md: "the
## whole world breathes vertically... Wisp rises and sinks ~2.5 m on a 20 s
## cycle"). A slow sine drives its Y position only (never rotation — the
## whale doesn't tilt, it just rises and sinks), `sync_to_physics = true` so
## the engine's kinematic platform motion carries every rider along
## correctly (breathing_chest.gd pattern, worlds/bramble/).
##
## Unlike BreathingChest, this node builds NO geometry of its own: the whole
## whale (tail/body/head mounds, flipper ledge, belly shelf, dorsal crest,
## dorsal slide, blowhole rim, water spout, tail seesaw) is added as children
## by wisp.gd, so "the whale is ONE AnimatableBody3D group" (world card) —
## every dreamling and prop physically on the whale rides this single body,
## rather than each part re-deriving its own drift math.

@export var amplitude: float = 2.5
@export var period: float = 20.0

var _rest_y: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	_rest_y = position.y


func _physics_process(delta: float) -> void:
	_time += delta
	position.y = _rest_y + sin(_time * TAU / period) * amplitude
