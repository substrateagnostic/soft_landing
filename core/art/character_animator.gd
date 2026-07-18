class_name CharacterAnimator
extends Node
## CharacterAnimator — D19. Drives a rigged character's AnimationTree from
## its PlayerBody's public state every physics frame. Lives as a child of a
## player's Visual node, sibling of the RiggedModelSlot that actually swaps
## in the merged rig scene (scenes/players/rigs/<id>_rig.tscn, see
## tools/import/merge_character_anims.gd). Builds the AnimationTree
## PROCEDURALLY, once, from whichever clips the rig's default
## AnimationLibrary actually contains -- nothing here hard-codes "Pip has
## skip, Otto has carry"; it discovers that at runtime, so a rig with a
## different clip set (a new gesture, a missing one) degrades gracefully
## instead of erroring.
##
## Root motion is OFF by design (research doc §6, D19): PlayerBody's
## CharacterBody3D fully owns velocity/position; the merge tool already
## zeroes each clip's baked horizontal Hips drift so playback never fights
## it. This script only ever *selects and blends* clips, never reads or
## writes world position.
##
## Squash-stretch survives untouched: PlayerBody's own
## _update_squash_stretch() scales the Visual node (this node's parent)
## every physics frame — a completely separate transform channel from the
## AnimationPlayer-driven Skeleton3D bone poses this script controls, so the
## two layers compose for free (skeletal animation, procedural squash on
## top), exactly the DIRECTION_V2/D19 requirement.
##
## Unknown-state fallback (PlayerBody.State "MAY GAIN NEW ONES like
## glide/pound" per brief): _resolve_body_target()'s `match` covers every
## state that exists today by name; anything it doesn't recognize falls
## through to the `_` branch, which uses only CharacterBody3D.is_on_floor()
## (a method every future state still has) to pick Locomotion vs. an
## airborne clip.

## Emitted when a fired one-shot gesture (wave/cheer/pickup/dance/sleep/
## skip/etc, whichever exist on this rig) finishes playing. Nothing in this
## pass wires gameplay systems (carry_toss.gd, dreamling pickup, ...) to
## play_gesture() -- core/coop/** is outside this task's territory -- so
## this signal currently has no in-repo listener; it's public plumbing for
## whoever does that wiring next.
signal gesture_finished(gesture_name: String)

const DEFAULT_MAX_SPEED: float = 4.0
const DEFAULT_TURN_SPEED: float = 8.0
const MOVED_EPSILON: float = 0.05
const BODY_BLEND_TIME: float = 0.2
const GESTURE_XFADE: float = 0.05
const GESTURE_FADE_IN: float = 0.15
const GESTURE_FADE_OUT: float = 0.2

const REQUIRED_LOCOMOTION: Array[String] = ["idle", "walk", "run"]
## clip name -> BodyTransition input node name. Only added if present on
## this particular rig's AnimationLibrary.
const OPTIONAL_BODY_CLIPS: Dictionary = {"jump": "Jump", "fall": "Fall", "carry": "Carry"}
const GESTURE_CLIPS: Array[String] = ["wave", "cheer", "pickup", "dance", "sleep", "skip"]

@export var rigged_model_slot_path: NodePath = ^"../RiggedModelSlot"
@export var player_body_path: NodePath = ^"../.."
## Fraction of tuning.move_speed treated as the BlendSpace1D "walk" point
## (0 = idle, this fraction = walk, 1.0 = run) -- horizontal speed is a
## true continuous 0..move_speed range (analog-stick magnitude scales it,
## see player_body.gd _apply_horizontal_movement), not a discrete gait.
@export var walk_speed_fraction: float = 0.5
@export var speed_smoothing: float = 12.0

var _player: PlayerBody = null
var _rigged_slot: RiggedModelSlot = null
var _carry_toss: CarryToss = null # Otto only; stays null on Pip, harmless
var _visual: Node3D = null

var _tree: AnimationTree = null
var _body_inputs: Dictionary = {} # String input name -> true
var _has_gesture_layer: bool = false
var _gesture_inputs: Dictionary = {} # String clip name -> true

var _smoothed_speed: float = 0.0
var _has_moved: bool = false # face-camera-at-rest latch, see _update_face_camera()
var _gesture_was_active: bool = false
var _last_gesture: String = ""


func _ready() -> void:
	_player = get_node_or_null(player_body_path) as PlayerBody
	_rigged_slot = get_node_or_null(rigged_model_slot_path) as RiggedModelSlot
	_visual = get_parent() as Node3D

	if _player == null:
		push_warning("CharacterAnimator: no PlayerBody at %s" % player_body_path)
		return
	if _rigged_slot == null:
		push_warning("CharacterAnimator: no RiggedModelSlot at %s" % rigged_model_slot_path)
		return

	_carry_toss = _player.get_node_or_null("CarryToss") as CarryToss

	# Director integration (V2): presentation-layer reactions to gameplay
	# signals — first-use Moon lines for the new verbs (D17/D20), a cheer
	# gesture when a dream comes home, and a landing puff (graphics lane's
	# one-shot scene) on every touch-down.
	_player.state_changed.connect(_on_player_state_changed)
	GameState.dream_returned.connect(_on_dream_returned)

	if _rigged_slot.has_rig():
		_on_rig_ready(_rigged_slot.rig_root, _rigged_slot.anim_player)
	else:
		_rigged_slot.rig_ready.connect(_on_rig_ready)


func _on_rig_ready(_rig_root: Node3D, anim_player: AnimationPlayer) -> void:
	_build_tree(anim_player)


const FOOTSTEP_PUFF_SCENE: PackedScene = preload("res://core/env/footstep_puff.tscn")

## First-use celebration lines: once per session, shared across both kids
## (static — Pip fluttering means Otto's first flutter stays quiet too).
static var _move_line_said: Dictionary = {}

var _was_on_floor: bool = true


func _on_player_state_changed(new_state: int) -> void:
	var key: String = ""
	match new_state:
		PlayerBody.State.FLUTTER:
			key = "move_flutter_first"
		PlayerBody.State.GLIDE:
			key = "move_glide_first"
		PlayerBody.State.POUND:
			key = "move_pound_first"
	if key.is_empty() or bool(_move_line_said.get(key, false)):
		return
	_move_line_said[key] = true
	TheMoon.say(key)


func _on_dream_returned(_world_id: String, _id: String) -> void:
	if _player != null and _player.is_on_floor():
		play_gesture("cheer")


func _spawn_landing_puff() -> void:
	var puff: Node3D = FOOTSTEP_PUFF_SCENE.instantiate() as Node3D
	if puff == null:
		return
	get_tree().current_scene.add_child(puff)
	var anchor: Node3D = _player.get_node_or_null("ReadabilityAnchor") as Node3D
	puff.global_position = anchor.global_position if anchor != null else _player.global_position
	if puff.has_method("puff"):
		puff.call("puff")


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var on_floor: bool = _player.is_on_floor()
	if on_floor and not _was_on_floor:
		_spawn_landing_puff()
	_was_on_floor = on_floor
	_update_face_camera(delta)
	if _tree == null:
		return

	var target: String = _resolve_body_target()
	if _body_inputs.has(target):
		_tree.set("parameters/BodyTransition/transition_request", target)

	var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	var weight: float = 1.0 - exp(-speed_smoothing * delta)
	_smoothed_speed = lerpf(_smoothed_speed, speed, weight)
	_tree.set("parameters/Locomotion/blend_position", _smoothed_speed)

	if _has_gesture_layer:
		var active_now: bool = bool(_tree.get("parameters/GestureOneShot/active"))
		if _gesture_was_active and not active_now:
			gesture_finished.emit(_last_gesture)
		_gesture_was_active = active_now


# ---------------------------------------------------------------------------
# Body-state selection
# ---------------------------------------------------------------------------

func _resolve_body_target() -> String:
	if _carry_toss != null and _carry_toss.is_carrying() and _body_inputs.has("Carry"):
		return "Carry"
	match _player.state:
		PlayerBody.State.GROUNDED, PlayerBody.State.CARRIED, PlayerBody.State.BUBBLED:
			return "Locomotion" # velocity is zeroed on CARRIED/BUBBLED entry -> reads as idle
		PlayerBody.State.RISING, PlayerBody.State.APEX:
			return "Jump" if _body_inputs.has("Jump") else _airborne_fallback()
		PlayerBody.State.FALLING:
			return "Fall" if _body_inputs.has("Fall") else "Locomotion"
		PlayerBody.State.TOSSED:
			return _airborne_fallback()
		_:
			# A state this script doesn't know about yet (glide/pound/...).
			return "Locomotion" if _player.is_on_floor() else _airborne_fallback()


func _airborne_fallback() -> String:
	if _body_inputs.has("Jump") and _player.velocity.y > 0.0:
		return "Jump"
	return "Fall" if _body_inputs.has("Fall") else "Locomotion"


# ---------------------------------------------------------------------------
# Face-the-camera-at-rest (polish queue item)
# ---------------------------------------------------------------------------

## Until the very first real movement (horizontal velocity or a jump),
## gently turn the Visual node to face whatever camera is active, so a
## freshly-spawned Pip/Otto presents to the player instead of standing in
## an arbitrary spawn-rotation. Latches permanently once movement starts --
## after that, player_body.gd's own _apply_horizontal_movement() owns
## Visual.rotation.y and this function is a no-op forever (read-only
## integration: it only ever writes when player_body.gd provably hasn't
## touched rotation yet this run, never fights it mid-game).
func _update_face_camera(delta: float) -> void:
	if _has_moved:
		return
	if _player.velocity.length_squared() > MOVED_EPSILON * MOVED_EPSILON or _player.state != PlayerBody.State.GROUNDED:
		_has_moved = true
		return
	if _visual == null:
		return
	# D27 split-screen: present to THIS seat's own camera when the director
	# has assigned one; the root viewport's camera is a mirror of Pip's half.
	var camera: Camera3D = _player.control_camera if is_instance_valid(_player.control_camera) else null
	if camera == null:
		var viewport: Viewport = get_viewport()
		camera = viewport.get_camera_3d() if viewport != null else null
	if camera == null:
		return
	var to_camera: Vector3 = camera.global_position - _visual.global_position
	to_camera.y = 0.0
	if to_camera.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(to_camera.x, to_camera.z)
	var turn_speed: float = _player.tuning.turn_speed if _player.tuning != null else DEFAULT_TURN_SPEED
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, turn_speed * delta)


# ---------------------------------------------------------------------------
# Gesture API (public plumbing -- see `gesture_finished` docstring)
# ---------------------------------------------------------------------------

func play_gesture(gesture_name: String) -> bool:
	if _tree == null or not _gesture_inputs.has(gesture_name):
		return false
	_tree.set("parameters/GestureSelect/transition_request", gesture_name)
	_tree.set("parameters/GestureOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_last_gesture = gesture_name
	return true


func is_gesture_active() -> bool:
	if _tree == null or not _has_gesture_layer:
		return false
	return bool(_tree.get("parameters/GestureOneShot/active"))


func has_animation_tree() -> bool:
	return _tree != null


# ---------------------------------------------------------------------------
# Procedural AnimationTree build
# ---------------------------------------------------------------------------

func _build_tree(anim_player: AnimationPlayer) -> void:
	if not anim_player.has_animation_library(""):
		push_warning("CharacterAnimator: rig has no default animation library")
		return
	var lib: AnimationLibrary = anim_player.get_animation_library("")
	var available: Dictionary = {}
	for clip: StringName in lib.get_animation_list():
		available[String(clip)] = true

	for required: String in REQUIRED_LOCOMOTION:
		if not available.has(required):
			push_warning("CharacterAnimator: rig missing required clip '%s' -- no AnimationTree built" % required)
			return

	var blend_tree := AnimationNodeBlendTree.new()
	var max_speed: float = _player.tuning.move_speed if _player.tuning != null else DEFAULT_MAX_SPEED

	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.set_min_space(0.0)
	locomotion.set_max_space(max_speed)
	locomotion.add_blend_point(_anim_node("idle"), 0.0)
	locomotion.add_blend_point(_anim_node("walk"), max_speed * walk_speed_fraction)
	locomotion.add_blend_point(_anim_node("run"), max_speed)
	blend_tree.add_node("Locomotion", locomotion)

	var body_names: Array[String] = ["Locomotion"]
	for clip_name: String in OPTIONAL_BODY_CLIPS:
		if available.has(clip_name):
			var body_node_name: String = OPTIONAL_BODY_CLIPS[clip_name]
			blend_tree.add_node(body_node_name, _anim_node(clip_name))
			body_names.append(body_node_name)

	var body_transition := AnimationNodeTransition.new()
	body_transition.xfade_time = BODY_BLEND_TIME
	body_transition.input_count = body_names.size()
	for i: int in body_names.size():
		body_transition.set("input_%d/name" % i, body_names[i])
	blend_tree.add_node("BodyTransition", body_transition)
	# connect_node() requires the target ("BodyTransition") to already exist
	# in the tree, hence a separate pass after add_node() above.
	for i: int in body_names.size():
		blend_tree.connect_node("BodyTransition", i, body_names[i])

	_body_inputs.clear()
	for n: String in body_names:
		_body_inputs[n] = true

	var gesture_names: Array[String] = []
	for clip_name: String in GESTURE_CLIPS:
		if available.has(clip_name):
			gesture_names.append(clip_name)
			blend_tree.add_node(clip_name, _anim_node(clip_name))

	var output_source: String = "BodyTransition"
	_has_gesture_layer = not gesture_names.is_empty()
	if _has_gesture_layer:
		var gesture_select := AnimationNodeTransition.new()
		gesture_select.xfade_time = GESTURE_XFADE
		gesture_select.input_count = gesture_names.size()
		for i: int in gesture_names.size():
			gesture_select.set("input_%d/name" % i, gesture_names[i])
		blend_tree.add_node("GestureSelect", gesture_select)
		for i: int in gesture_names.size():
			blend_tree.connect_node("GestureSelect", i, gesture_names[i])

		var one_shot := AnimationNodeOneShot.new()
		one_shot.mix_mode = AnimationNodeOneShot.MIX_MODE_BLEND
		one_shot.fadein_time = GESTURE_FADE_IN
		one_shot.fadeout_time = GESTURE_FADE_OUT
		blend_tree.add_node("GestureOneShot", one_shot)
		blend_tree.connect_node("GestureOneShot", 0, "BodyTransition")
		blend_tree.connect_node("GestureOneShot", 1, "GestureSelect")
		output_source = "GestureOneShot"

	_gesture_inputs.clear()
	for n: String in gesture_names:
		_gesture_inputs[n] = true

	blend_tree.connect_node("output", 0, output_source)

	_tree = AnimationTree.new()
	add_child(_tree)
	_tree.tree_root = blend_tree
	_tree.anim_player = _tree.get_path_to(anim_player)
	_tree.active = true

	print("CHARACTER_ANIMATOR_READY %s" % JSON.stringify({
		"player": String(_player.name),
		"body_inputs": body_names,
		"gestures": gesture_names,
	}))


func _anim_node(clip_name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = StringName(clip_name)
	return node
