class_name Dreamkeeper
extends Node3D
## Dreamkeeper — Dressing M2 (aliveness_wow.md §5/§11, "hub-as-visible-
## progress-bar" / Astro Crash Site / Kirby Waddle Dee Town / Spyro
## Homeworlds model): a small, zero-dialogue resident who lives at a fixed
## spot in a world and simply notices you. No quest, no text, no fail
## state -- presence only (bible law: the Moon talks, the world gestures).
##
## Behavior loop, entirely local (no world-script wiring beyond spawning
## this node at a position -- see pillow_fort.gd/wisp.gd's
## `_build_dreamkeepers()`):
##   ASLEEP  -- plays the "sleep" clip, facing its authored `face_yaw_degrees`.
##   AWAKE   -- a player is within `WAKE_RADIUS`: plays "idle", turns
##              smoothly to face the nearest player, waves once shortly
##              after waking, then waves again every so often while anyone
##              stays close.
##   (back to ASLEEP `SLEEP_DELAY` seconds after the last player leaves
##   `WAKE_RADIUS` -- a settle-out delay, not an instant snap.)
## Independently, ANY `GameState.dream_returned` (own world or not --
## "even from afar" per the brief) interrupts whatever is playing for one
## "cheer" clip, then resumes idle/sleep exactly where the state machine
## already had it.
##
## Rig loading reuses RiggedModelSlot verbatim (core/art/rigged_model_slot.gd)
## for the scale/ground contract -- built here at runtime (not pre-authored
## in dreamkeeper.tscn) because `rig_id` varies per instance (lamb_keeper vs
## moth_shepherd) and RiggedModelSlot reads `model_id` in its own _ready(),
## which this codebase has repeatedly confirmed does NOT run synchronously
## inside add_child() (critter.gd's `kind`/`world_id` doc comment, TailBridge's
## position-before-add_child note) -- so `model_id`/`target_height` are set
## on the slot BEFORE add_child(), and rig-readiness is read via
## `has_rig()`/`rig_root`/`anim_player` OR the `rig_ready` signal, covering
## both possible orderings exactly like core/art/character_animator.gd does.
##
## No collision shape (deliberate): a Dreamkeeper is pure presence, never a
## physical obstacle -- matches the "generosity floor" every other small,
## walk-through prop in this pass follows, and guarantees it can never block
## a scripted harness route regardless of where it's placed.

enum State { ASLEEP, AWAKE }

const PLAYERS_GROUP: String = "players"

## rig id -> target world-space height (brief: lamb 0.85, moth 1.0). An
## unlisted rig id falls back to DEFAULT_HEIGHT rather than erroring --
## same generosity-by-default convention as MissionRegistry/critter data.
const RIG_HEIGHTS: Dictionary = {"lamb_keeper": 0.85, "moth_shepherd": 1.0}
const DEFAULT_HEIGHT: float = 1.0

const WAKE_RADIUS: float = 4.0
const SLEEP_DELAY: float = 6.0
const FACE_TURN_SPEED: float = 6.0
const WAKE_FIRST_WAVE_DELAY: float = 1.0 # lets the turn-to-face read before the first wave
const IDLE_WAVE_INTERVAL_MIN: float = 5.0
const IDLE_WAVE_INTERVAL_MAX: float = 9.0
const RECEIPT_COOLDOWN: float = 0.5 # rate-limits the DREAMKEEPER receipt (critter.gd/touch_react.gd pattern)

## Set by the spawning world script BEFORE add_child (see this file's own
## header + pillow_fort.gd/wisp.gd `_spawn_dreamkeeper()`).
@export var keeper_id: String = ""
@export var rig_id: String = ""
@export var face_yaw_degrees: float = 0.0

var _state: State = State.ASLEEP
var _anim: AnimationPlayer = null
var _visual: Node3D = null
var _away_timer: float = 0.0
var _idle_wave_timer: float = 0.0
var _receipt_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("dreamkeeper")
	rotation.y = deg_to_rad(face_yaw_degrees)
	_build_rig()
	GameState.dream_returned.connect(_on_dream_returned)


func _build_rig() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var height: float = float(RIG_HEIGHTS.get(rig_id, DEFAULT_HEIGHT))

	# Grey-box fallback -- visible until (and unless) the merged rig scene
	# loads. D10/D19 seam contract: RiggedModelSlot silently no-ops without
	# erroring if scenes/players/rigs/<rig_id>_rig.tscn is missing, so this
	# primitive must remain fully present regardless.
	var primitive := MeshInstance3D.new()
	primitive.name = "Primitive"
	var mesh := CapsuleMesh.new()
	mesh.radius = height * 0.22
	mesh.height = height
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("C9D4E4") if rig_id == "moth_shepherd" else Color("F5F2E8")
	mesh.material = mat
	primitive.mesh = mesh
	primitive.position = Vector3(0.0, height * 0.5, 0.0)
	_visual.add_child(primitive)

	var slot := RiggedModelSlot.new()
	slot.name = "RiggedModelSlot"
	slot.model_id = rig_id
	slot.target_height = height
	slot.ground_offset_y = 0.0
	_visual.add_child(slot)

	if slot.has_rig():
		_on_rig_ready(slot.rig_root, slot.anim_player)
	else:
		slot.rig_ready.connect(_on_rig_ready)


func _on_rig_ready(_rig_root: Node3D, anim_player: AnimationPlayer) -> void:
	_anim = anim_player
	_anim.animation_finished.connect(_on_animation_finished)
	_sync_animation_to_state()


func _on_animation_finished(anim_name: StringName) -> void:
	# wave/cheer are one-shots (no loop_mode on either clip, confirmed
	# against both rig .tscn files) -- once either finishes, fall back to
	# whichever ambient loop the state machine currently calls for.
	if String(anim_name) == "wave" or String(anim_name) == "cheer":
		_sync_animation_to_state()


func _physics_process(delta: float) -> void:
	_receipt_cooldown = max(_receipt_cooldown - delta, 0.0)
	var nearest: PlayerBody = _nearest_player()
	var nearest_dist: float = nearest.global_position.distance_to(global_position) if nearest != null else INF
	_update_state(delta, nearest_dist)
	_update_facing(delta, nearest)


func _nearest_player() -> PlayerBody:
	var best: PlayerBody = null
	var best_dist: float = INF
	for node: Node in get_tree().get_nodes_in_group(PLAYERS_GROUP):
		var player: PlayerBody = node as PlayerBody
		if player == null:
			continue
		var dist: float = player.global_position.distance_to(global_position)
		if dist < best_dist:
			best_dist = dist
			best = player
	return best


func _update_state(delta: float, nearest_dist: float) -> void:
	match _state:
		State.ASLEEP:
			if nearest_dist < WAKE_RADIUS:
				_enter_awake()
		State.AWAKE:
			if nearest_dist < WAKE_RADIUS:
				_away_timer = 0.0
				_idle_wave_timer -= delta
				if _idle_wave_timer <= 0.0:
					_fire_wave()
					_idle_wave_timer = randf_range(IDLE_WAVE_INTERVAL_MIN, IDLE_WAVE_INTERVAL_MAX)
			else:
				_away_timer += delta
				if _away_timer >= SLEEP_DELAY:
					_enter_asleep()


## Smoothly turns to face whoever is nearest while AWAKE (character_animator.
## gd's _update_face_camera lerp_angle pattern); otherwise eases back to the
## authored resting orientation -- covers both "settling back to sleep" and
## the boot-time default before anyone has ever come close.
func _update_facing(delta: float, nearest: PlayerBody) -> void:
	var target_yaw: float = deg_to_rad(face_yaw_degrees)
	if _state == State.AWAKE and nearest != null:
		var to_player: Vector3 = nearest.global_position - global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.0001:
			target_yaw = atan2(to_player.x, to_player.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, FACE_TURN_SPEED * delta)


func _enter_awake() -> void:
	if _state == State.AWAKE:
		return
	_state = State.AWAKE
	_away_timer = 0.0
	_idle_wave_timer = WAKE_FIRST_WAVE_DELAY
	_play("idle")
	_emit_receipt("wake")


func _enter_asleep() -> void:
	if _state == State.ASLEEP:
		return
	_state = State.ASLEEP
	_play("sleep")
	_emit_receipt("sleep")


func _fire_wave() -> void:
	if _anim == null or not _anim.has_animation("wave"):
		return
	_anim.play("wave")
	_emit_receipt("wave")


## "when a dream is returned anywhere ... CHEER once even from afar" -- fires
## regardless of `_state`/distance, and deliberately does NOT touch `_state`
## itself (a keeper asleep two worlds away cheers once, then keeps sleeping).
func _on_dream_returned(_world_id: String, _id: String) -> void:
	if _anim == null or not _anim.has_animation("cheer"):
		return
	_anim.play("cheer")
	_emit_receipt("cheer")


func _sync_animation_to_state() -> void:
	if _anim == null:
		return
	_play("idle" if _state == State.AWAKE else "sleep")


func _play(anim_name: String) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _anim.current_animation != anim_name:
		_anim.play(anim_name)


func _emit_receipt(event: String) -> void:
	if _receipt_cooldown > 0.0:
		return
	_receipt_cooldown = RECEIPT_COOLDOWN
	print("DREAMKEEPER %s" % JSON.stringify({"id": keeper_id, "event": event}))
