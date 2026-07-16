class_name Callie
extends Area3D
## Callie — the kids' stuffed calico cat (docs/design/world-cards/callie.md).
## NOT a giant: stuffy-sized, floppy, lying-down. Three states: NAPPING (home
## or wherever she was last set down — same slow breath-scale bob either
## way), CARRIED (perched near the carrier's shoulder, dream-sniffing +
## purring), SET_DOWN (a brief flop, then settles back into NAPPING).
##
## Pickup/set-down mirrors world_door.gd's "poll interact only while a body
## is inside" pattern: PickupRange is a 1.2 m CollisionShape3D, not a touch
## trigger, since the card's pickup range is proximity-based, not "must
## touch the model" (a plush her own size would be a tiny, fiddly target).
##
## World-switch survival (the subtle part — see callie-VERIFY.md for the
## full trace): CARRIED, she's parented under a CalliePerch that is itself a
## child of the carrier, and players persist across world switches
## (scenes/main.gd never frees $Players/*), so she survives for free. NOT
## carried (NAPPING or mid-flop SET_DOWN), she's a descendant of whichever
## world she's currently in; when that world unloads (main.gd's
## `_world.queue_free()`), she unloads with it — "stuffies teleport home"
## (docs/design/world-cards/callie.md) is really just: freed, then a fresh
## instance is built on the next pillow_fort load. The `active_instance`
## static guard is what stops that fresh build from ever duplicating a
## Callie who is still out being carried.

signal state_changed(new_state: int)

enum State { NAPPING, CARRIED, SET_DOWN }

const MEW_PATH: String = "res://assets/audio/sfx/mew_soft.ogg"
const PURR_PATH: String = "res://assets/audio/sfx/purr_loop.ogg"
const CALLIE_GROUP: String = "callie"
const DREAMLING_GROUP: String = "dreamling" # matches worlds/common/world_base.gd's DREAMLING_GROUP

## One Callie exists at a time (D-companion guard, callie-VERIFY.md §e).
## pillow_fort.gd reads this (state + is_instance_valid) before deciding
## whether _build_callie_home() should spawn a fresh nap-at-home instance.
static var active_instance: Callie = null

## Public (not `_state`) so pillow_fort.gd's duplicate guard can read it —
## mirrors PlayerBody's own public `state` var for the same reason.
var state: State = State.NAPPING

@export var perch_offset_x: float = 0.25
@export var perch_offset_y_ratio: float = 0.55
@export var claim_cooldown: float = 0.4
@export var sniff_radius: float = 8.0
@export var mew_cooldown: float = 4.0
@export var sniff_turn_speed: float = 4.0
@export var breath_period: float = 5.0
@export var breath_amplitude: float = 0.06
## D19 visual-life polish: a slow, tiny yaw wobble layered under the
## existing breath-scale bob while NAPPING -- deliberately a different
## period than breath_period so the two never lock into a single
## mechanical-looking cycle. Gameplay-inert (rotation only, no collision on
## this Area3D depends on facing).
@export var sway_period: float = 7.3
@export var sway_amplitude_deg: float = 3.0
## D19 polish: brief scale pulse on _play_mew() (a "perked up" reaction),
## reusing the same tween-squash idiom as _play_flop_tween() below.
@export var perk_pulse_up_duration: float = 0.12
@export var perk_pulse_down_duration: float = 0.18
@export var perk_pulse_scale: Vector3 = Vector3(1.08, 0.94, 1.08)
@export var flop_duration: float = 0.35
@export var set_down_forward_offset: float = 0.5
## Fallback perch height if a carrier's CollisionShape3D/CapsuleShape3D
## can't be found — should never trigger for Pip/Otto, only defensive.
@export var default_carrier_height: float = 1.0

@onready var _visual: Node3D = $FallbackVisual
@onready var _mew_player: AudioStreamPlayer3D = $MewPlayer
@onready var _purr_player: AudioStreamPlayer3D = $PurrPlayer

var _bodies_inside: Array[PlayerBody] = []
var _carrier: PlayerBody = null
var _claim_cooldown_timer: float = 0.0
var _mew_cooldown_timer: float = 0.0
var _breath_phase: float = 0.0
var _sway_phase: float = 0.0
var _sway_base_yaw: float = 0.0 # rotation.y at the moment NAPPING was (re)entered
## World-door bug guard: WorldDoor (worlds/common/world_door.gd) and Callie
## both independently read the SAME raw "p%d_interact just_pressed" signal
## with no consumption/arbitration between them. Carrying Callie through any
## door means the one press that opens the door is ALSO seen by her own
## CARRIED branch that same frame -- an involuntary set-down at the exact
## moment of a world switch, directly violating the card's "on world switch
## she stays with you." scenes/main.gd's WorldSlot subtree processes before
## Players (tree sibling order), so by the time this script's own
## _physics_process runs, GameState.current_world_id has ALREADY flipped in
## the same frame a door-triggered switch fires -- a reliable same-frame
## signal to suppress interact handling on, without reaching into
## world_door.gd/main.gd (outside this task's territory).
var _last_world_id: String = ""

## Session-scoped fallback for the one Moon line (docs/design/world-cards/
## callie.md: "once per save"). GameState has no `flags: Dictionary` seam
## and SaveManager's `_data` has no public read/write for arbitrary keys
## (only a private merge-unknown-keys-forward path on LOAD) — both files
## are outside this task's territory to extend. Documented deviation:
## once-per-SESSION instead of once-per-save (callie-VERIFY.md).
static var _dreams_line_said: bool = false


func _ready() -> void:
	add_to_group(CALLIE_GROUP)
	# Printed unconditionally (not just under a flag) so the duplicate-guard
	# property (callie-VERIFY.md §e) has a receipt at the exact moment any
	# instance becomes ready, whether that's the very first fort load or a
	# regression that spawned a second Callie alongside a carried one.
	print("CALLIE_COUNT %s" % JSON.stringify({"count": get_tree().get_nodes_in_group(CALLIE_GROUP).size()}))

	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2 # PlayerBody layer (dreamling.gd / world_door.gd convention)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	Callie.active_instance = self
	_last_world_id = GameState.current_world_id
	_load_audio()
	_set_state(State.NAPPING)


func _load_audio() -> void:
	# Fail-soft (AudioManager's own convention): missing files are the
	# expected state until this task's own audio-gen step has run.
	if ResourceLoader.exists(MEW_PATH):
		_mew_player.stream = load(MEW_PATH) as AudioStream
	if ResourceLoader.exists(PURR_PATH):
		_purr_player.stream = load(PURR_PATH) as AudioStream


func _physics_process(delta: float) -> void:
	_claim_cooldown_timer = max(_claim_cooldown_timer - delta, 0.0)

	var world_id_now: String = GameState.current_world_id
	var world_just_changed: bool = world_id_now != _last_world_id
	_last_world_id = world_id_now
	if not world_just_changed:
		_process_interact()

	match state:
		State.NAPPING:
			_process_napping(delta)
		State.CARRIED:
			_process_carried(delta)
		State.SET_DOWN:
			pass # flop is driven by the Tween started in _play_flop_tween()


# ---------------------------------------------------------------------------
# Pickup / set-down
# ---------------------------------------------------------------------------

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerBody and not _bodies_inside.has(body):
		_bodies_inside.append(body as PlayerBody)


func _on_body_exited(body: Node3D) -> void:
	_bodies_inside.erase(body)


## Poll-only-while-a-body-is-inside (world_door.gd's own pattern), gated by
## a claim cooldown so a pickup can never immediately consume the same press
## as a set-down (or vice versa) in adjacent frames.
func _process_interact() -> void:
	if _claim_cooldown_timer > 0.0:
		return
	if _bodies_inside.is_empty():
		return
	match state:
		State.NAPPING:
			for body: PlayerBody in _bodies_inside:
				if Input.is_action_just_pressed("p%d_interact" % body.seat):
					_pick_up(body)
					_claim_cooldown_timer = claim_cooldown
					return
		State.CARRIED:
			if _carrier != null and Input.is_action_just_pressed("p%d_interact" % _carrier.seat):
				_set_down()
				_claim_cooldown_timer = claim_cooldown


func _pick_up(carrier: PlayerBody) -> void:
	_carrier = carrier
	_visual.scale = Vector3.ONE # in case she was mid-breath-bob or mid-flop

	var perch := Node3D.new()
	perch.name = "CalliePerch"
	perch.position = _perch_offset(carrier)
	carrier.add_child(perch)

	var prev_parent: Node = get_parent()
	if prev_parent != null:
		prev_parent.remove_child(self)
	perch.add_child(self)
	position = Vector3.ZERO
	rotation = Vector3.ZERO

	_mew_cooldown_timer = 0.0 # a freshly-carried Callie can mew right away
	_set_state(State.CARRIED)


func _set_down() -> void:
	var carrier_ref: PlayerBody = _carrier
	if carrier_ref == null:
		return

	var facing: Vector3 = _carrier_facing(carrier_ref)
	var half_height: float = _carrier_collision_height(carrier_ref) * 0.5
	var drop_pos: Vector3 = carrier_ref.global_position + facing * set_down_forward_offset
	drop_pos.y = carrier_ref.global_position.y - half_height # ground, not shoulder height

	_purr_player.stop()

	# Resolve the target parent BEFORE leaving the tree below: remove_child()
	# detaches `self` from the SceneTree immediately, and get_tree() (which
	# both _current_world_root() and the current_scene fallback need) returns
	# null on a detached node.
	var target_parent: Node = _current_world_root()
	if target_parent == null:
		target_parent = get_tree().current_scene

	var perch: Node = get_parent()
	if perch != null:
		perch.remove_child(self)

	target_parent.add_child(self)
	global_position = drop_pos
	_visual.rotation.y = 0.0

	if perch != null and perch.name == "CalliePerch":
		perch.queue_free()

	_carrier = null
	_set_state(State.SET_DOWN)
	_play_flop_tween()


func _perch_offset(carrier: PlayerBody) -> Vector3:
	var height: float = _carrier_collision_height(carrier)
	return Vector3(perch_offset_x, height * perch_offset_y_ratio, 0.0)


func _carrier_collision_height(carrier: PlayerBody) -> float:
	var shape_node: CollisionShape3D = carrier.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		return (shape_node.shape as CapsuleShape3D).height
	return default_carrier_height


## Same technique as core/coop/carry_toss.gd's own `_otto_facing()` — not a
## shared call (that method is private to CarryToss), just the same small,
## generic yaw-to-forward-vector conversion re-implemented locally.
func _carrier_facing(carrier: PlayerBody) -> Vector3:
	var visual: Node3D = carrier.get_node_or_null("Visual") as Node3D
	if visual == null:
		return Vector3.FORWARD
	var yaw: float = visual.rotation.y
	return Vector3(sin(yaw), 0.0, cos(yaw))


## The node that gets `queue_free()`'d by scenes/main.gd on every world
## switch — i.e. WorldSlot's current child. Deliberately NOT
## `get_tree().current_scene` (that resolves to the persistent "Main" node
## itself here — see core/coop/carry_toss.gd and core/coop/seat_manager.gd,
## which both reparent onto it for exactly the opposite reason: content that
## must survive a world switch). Walking down from `current_scene` to its
## known "WorldSlot" child stays inside the documented public tree shape
## (scenes/main.tscn) without editing scenes/main.gd to expose anything new.
func _current_world_root() -> Node3D:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null:
		return null
	var world_slot: Node = main_scene.get_node_or_null("WorldSlot")
	if world_slot == null or world_slot.get_child_count() == 0:
		return null
	return world_slot.get_child(0) as Node3D


# ---------------------------------------------------------------------------
# NAPPING — breath-scale bob + a slow micro-sway (D19 visual-life polish)
# ---------------------------------------------------------------------------

func _process_napping(delta: float) -> void:
	_breath_phase = fmod(_breath_phase + delta * TAU / breath_period, TAU)
	var s: float = 1.0 + sin(_breath_phase) * breath_amplitude
	_visual.scale = Vector3(1.0, s, 1.0)

	_sway_phase = fmod(_sway_phase + delta * TAU / sway_period, TAU)
	var sway_rad: float = deg_to_rad(sway_amplitude_deg) * sin(_sway_phase)
	_visual.rotation.y = _sway_base_yaw + sway_rad


# ---------------------------------------------------------------------------
# SET_DOWN — flop tween, then quietly resume napping in place
# ---------------------------------------------------------------------------

func _play_flop_tween() -> void:
	_visual.scale = Vector3.ONE
	var squash: Vector3 = Vector3(1.3, 0.65, 1.3)
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", squash, flop_duration * 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_visual, "scale", Vector3.ONE, flop_duration * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_flop_finished)


func _on_flop_finished() -> void:
	if state == State.SET_DOWN:
		_set_state(State.NAPPING, false) # silent: "then naps where placed" is the same NAPPING loop, not a new receipt-worthy transition


# ---------------------------------------------------------------------------
# CARRIED — dream-sniffing, purring, the one Moon line
# ---------------------------------------------------------------------------

func _process_carried(delta: float) -> void:
	_mew_cooldown_timer = max(_mew_cooldown_timer - delta, 0.0)
	if _carrier == null or not is_instance_valid(_carrier):
		return

	_maybe_speak_marmalade_line()

	var target: Dreamling = _nearest_sniffable_dreamling()
	if target != null:
		_face_toward(target.global_position, delta)
		if _mew_cooldown_timer <= 0.0:
			_mew_cooldown_timer = mew_cooldown
			_play_mew(target.id)

	_update_purr()


## `monitoring == true` is Dreamling's public "still IDLE / not yet
## collected" proxy (its `_state` is private): _start_following sets
## `monitoring = false` via set_deferred the moment a dreamling is caught,
## and it never flips back true through FOLLOWING or RELEASING.
func _nearest_sniffable_dreamling() -> Dreamling:
	var best: Dreamling = null
	var best_dist: float = sniff_radius
	for node: Node in get_tree().get_nodes_in_group(DREAMLING_GROUP):
		var candidate: Dreamling = node as Dreamling
		if candidate == null or not candidate.monitoring:
			continue
		var dist: float = candidate.global_position.distance_to(global_position)
		if dist < best_dist:
			best_dist = dist
			best = candidate
	return best


func _face_toward(target_position: Vector3, delta: float) -> void:
	var to_target: Vector3 = target_position - global_position
	if to_target.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(to_target.x, to_target.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, sniff_turn_speed * delta)


func _play_mew(target_id: String) -> void:
	# "t" (physics frame) lets a receipt log prove the >=4 s cooldown
	# property directly, the same convention harness.gd's own EVT/PLAYER_POS
	# lines use.
	print("CALLIE_MEW %s" % JSON.stringify({"target": target_id, "t": Engine.get_physics_frames()}))
	if _mew_player.stream != null:
		_mew_player.play()
	_play_perk_pulse()


## D19 visual-life polish: a small "perked up" scale pulse each time she
## mews, reusing _play_flop_tween()'s tween-squash idiom. Purely cosmetic —
## does not touch _play_mew()'s own cooldown/targeting/audio logic above.
func _play_perk_pulse() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", perk_pulse_scale, perk_pulse_up_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_visual, "scale", Vector3.ONE, perk_pulse_down_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _update_purr() -> void:
	if _carrier == null:
		if _purr_player.playing:
			_purr_player.stop()
		return
	var should_purr: bool = Dreamling.carried_by(_carrier).size() > 0
	if should_purr and not _purr_player.playing and _purr_player.stream != null:
		_purr_player.play()
	elif not should_purr and _purr_player.playing:
		_purr_player.stop()


func _maybe_speak_marmalade_line() -> void:
	if GameState.current_world_id != "marmalade":
		return
	if _dreams_line_said:
		return
	_dreams_line_said = true
	TheMoon.say("callie_dreams")


# ---------------------------------------------------------------------------
# State receipts
# ---------------------------------------------------------------------------

func _set_state(new_state: State, announce: bool = true) -> void:
	if new_state == State.NAPPING and _visual != null:
		# Re-anchor the micro-sway to wherever she's currently facing (not
		# always yaw=0) and restart its phase at zero so it eases in from the
		# resting pose instead of snapping.
		_sway_base_yaw = _visual.rotation.y
		_sway_phase = 0.0
	state = new_state
	state_changed.emit(state)
	if announce:
		_emit_state_receipt()


func _emit_state_receipt() -> void:
	var payload: Dictionary = {"state": _state_name()}
	if state == State.CARRIED and _carrier != null:
		payload["seat"] = _carrier.seat
	print("CALLIE %s" % JSON.stringify(payload))


## True if this instance is guaranteed to still exist once any pending
## deferred frees resolve -- i.e. no ancestor up to the tree root is
## currently queued for deletion. pillow_fort.gd's own duplicate guard
## (_build_callie_home()) calls this instead of checking `state == CARRIED`
## directly: `queue_free()` only defers the free (the actual removal
## happens later that same frame), so immediately after a door-triggered
## world switch (main.gd's `_world.queue_free()` followed synchronously by
## loading + `_ready()`-ing the next world), a SET_DOWN Callie who was left
## behind in the world that JUST got queue_free()'d is technically still
## `is_instance_valid()` for one more frame -- a naive validity/state check
## would wrongly treat her as "still around" and skip spawning the fresh
## nap-at-home instance, leaving zero live Callies once the deferred free
## actually lands. Walking the ancestor chain for `is_queued_for_deletion()`
## catches that same-frame window; a CARRIED Callie is unaffected (she was
## reparented under her persistent carrier well before any world housing
## her was ever freed, so she's never inside a freed subtree to begin
## with). Confirmed against both round-trip shapes in callie-VERIFY.md §e.
func will_persist() -> bool:
	var current: Node = self
	while current != null:
		if current.is_queued_for_deletion():
			return false
		current = current.get_parent()
	return true


func _state_name() -> String:
	match state:
		State.NAPPING:
			return "napping"
		State.CARRIED:
			return "carried"
		State.SET_DOWN:
			return "set_down"
	return "unknown"
