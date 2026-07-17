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
##
## THE DIVE (worlds/wisp/dive_sequence.gd, ROADMAP M3): begin_settle()/
## settle_immediately() retarget `_rest_y`/`amplitude` themselves rather than
## letting an outside tween fight `_physics_process`'s own per-frame
## `position.y` write (which would just get overwritten the very next
## physics tick) — the exact same "single source of truth" reasoning
## breathing_chest.gd / the compound-body architecture already leans on
## elsewhere in this world. Tweening `_rest_y` keeps the existing bob math
## live throughout the whole descent, so the whale keeps breathing (at a
## shrinking amplitude, per the tween below) all the way down instead of
## freezing mid-motion.

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


## begin_settle — THE DIVE: tweens `_rest_y` down to `new_rest_y` over
## `duration` seconds (SINE ease, matching every other set-piece tween in
## this codebase — rollover_sequence.gd's haunch settle, mountain_dressing's
## cloud blow), then locks `amplitude` down to `new_amplitude` (a small
## residual breath, D25's "±0.3 m drift budget" language reused here) once
## the descent finishes. Safe to call exactly once per sequence (dive_
## sequence.gd's own `_played` guard already prevents a second call).
func begin_settle(new_rest_y: float, duration: float, new_amplitude: float) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "_rest_y", new_rest_y, duration)
	tween.finished.connect(func() -> void:
		amplitude = new_amplitude
	)


## settle_immediately — a revisit after a PRIOR session already completed
## the dive (SPEC.md D14, "the world remembers"): no tween, matching
## rollover_sequence.gd's own _apply_already_open_state() no-animation
## convention for a world that reopens already in its final state.
func settle_immediately(new_rest_y: float, new_amplitude: float) -> void:
	_rest_y = new_rest_y
	amplitude = new_amplitude
	position.y = new_rest_y # avoids a one-frame flash at the old rest height
	# before _physics_process's next tick recomputes it.
