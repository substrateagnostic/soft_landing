class_name PlayerBody
extends CharacterBody3D
## PlayerBody — shared movement core for Pip and Otto (SPEC.md). Every feel
## number lives in `tuning` (a MovementTuning resource); this script holds
## no magic numbers. Extends (not rewrites) the basic accel/decel + derived
## gravity + coyote/buffer core with the full state machine: GROUNDED /
## RISING / APEX / FALLING (auto-computed each frame) and CARRIED / TOSSED /
## BUBBLED (entered/exited by carry_toss.gd and soft_landing.gd via the
## enter_carried()/enter_bubbled()/launch()/exit_special_state() API).
## Squash-stretch on the Visual node reads state each frame.

signal jumped
signal landed
signal state_changed(new_state: int)

enum State { GROUNDED, RISING, APEX, FALLING, CARRIED, TOSSED, BUBBLED }

const PLAYER_COLLISION_LAYER: int = 2 # D7: both kids share this layer
const PLAYER_COLLISION_MASK: int = 1 # world geometry only -> no player-player collision

@export var seat: int = 1
@export var tuning: MovementTuning

@onready var _visual: Node3D = get_node_or_null("Visual") as Node3D

var state: State = State.GROUNDED

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _virtual_jump_requested: bool = false
var _rise_gravity: float = 0.0
var _fall_gravity: float = 0.0

var _control_enabled: bool = true
var _virtual_input: Vector2 = Vector2.ZERO
var _virtual_input_enabled: bool = false

var _squash_timer: float = 0.0
var _visual_scale: Vector3 = Vector3.ONE

var _move_action_left: String
var _move_action_right: String
var _move_action_up: String
var _move_action_down: String
var _jump_action: String


func _ready() -> void:
	var prefix: String = "p%d_" % seat
	_move_action_left = prefix + "move_left"
	_move_action_right = prefix + "move_right"
	_move_action_up = prefix + "move_up"
	_move_action_down = prefix + "move_down"
	_jump_action = prefix + "jump"

	floor_constant_speed = true
	platform_on_leave = PLATFORM_ON_LEAVE_ADD_UPWARD_VELOCITY
	collision_layer = PLAYER_COLLISION_LAYER
	collision_mask = PLAYER_COLLISION_MASK

	add_to_group("player")
	add_to_group("player_seat_%d" % seat)

	if tuning != null:
		# h = 1/2 * g * t^2 at apex, v0 = g*t -> g = 2h/t^2. Gravity is
		# always derived from jump_height/time_to_apex, never hand-set (D3).
		_rise_gravity = (2.0 * tuning.jump_height) / (tuning.time_to_apex * tuning.time_to_apex)
		_fall_gravity = _rise_gravity * tuning.fall_gravity_mult
		floor_snap_length = tuning.floor_snap


func _physics_process(delta: float) -> void:
	if tuning == null:
		return

	if state == State.CARRIED or state == State.BUBBLED:
		# Position is driven externally (parented to a carry socket, or
		# tweened by a BubbleEffect) — no input, no gravity, no collision.
		_update_squash_stretch(delta)
		return

	var was_on_floor: bool = is_on_floor()

	if was_on_floor:
		_coyote_timer = tuning.coyote_time
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	_apply_gravity(was_on_floor, delta)

	if state == State.TOSSED:
		pass # ballistic — no horizontal control and no jump until apex is reached
	else:
		_apply_horizontal_movement(was_on_floor, delta)
		_update_jump_buffer(delta)
		_try_jump(was_on_floor) # may zero _coyote_timer if it consumes the jump this frame

	move_and_slide()

	var on_floor_now: bool = is_on_floor()
	if on_floor_now and not was_on_floor:
		landed.emit()
		_squash_timer = tuning.squash_duration

	_update_state(on_floor_now)
	_update_squash_stretch(delta)


func _apply_gravity(on_floor: bool, delta: float) -> void:
	if on_floor:
		return
	var gravity: float = _rise_gravity if velocity.y > 0.0 else _fall_gravity
	if state == State.APEX:
		gravity *= tuning.apex_gravity_mult # the flutter window
	velocity.y = max(velocity.y - gravity * delta, -tuning.terminal_velocity)


func _apply_horizontal_movement(on_floor: bool, delta: float) -> void:
	var input_vec: Vector2 = Vector2.ZERO
	if _control_enabled:
		input_vec = _virtual_input if _virtual_input_enabled else Input.get_vector(
			_move_action_left, _move_action_right, _move_action_up, _move_action_down
		)
	var move_dir: Vector3
	if _virtual_input_enabled:
		# BuddyAI computes world-space steering directly — no remap.
		move_dir = Vector3(input_vec.x, 0.0, input_vec.y)
	else:
		# Stick-up means "into the screen" (Mario 64 convention): remap the
		# stick through the live camera's yaw. The auto-camera's yaw is
		# heavily damped, so the frame is stable under the child's thumb.
		move_dir = _camera_relative_dir(input_vec)
	if move_dir.length_squared() > 1.0:
		move_dir = move_dir.normalized()

	var target: Vector3 = move_dir * tuning.move_speed
	var control: float = 1.0 if on_floor else tuning.air_control
	var rate: float = (tuning.accel if move_dir.length_squared() > 0.0 else tuning.decel) * control

	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if _visual != null and move_dir.length_squared() > 0.001:
		var target_yaw: float = atan2(move_dir.x, move_dir.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, tuning.turn_speed * delta)


func _camera_relative_dir(input_vec: Vector2) -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if camera == null:
		return Vector3(input_vec.x, 0.0, input_vec.y)
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3(input_vec.x, 0.0, input_vec.y)
	forward = forward.normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	return right * input_vec.x + forward * (-input_vec.y)


func _update_jump_buffer(delta: float) -> void:
	var pressed: bool = _virtual_jump_requested
	if not pressed and _control_enabled and not _virtual_input_enabled:
		pressed = Input.is_action_just_pressed(_jump_action)
	_virtual_jump_requested = false

	if pressed:
		_jump_buffer_timer = tuning.jump_buffer
	else:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)


func _try_jump(on_floor: bool) -> void:
	var can_jump: bool = on_floor or _coyote_timer > 0.0
	if _jump_buffer_timer > 0.0 and can_jump:
		velocity.y = sqrt(2.0 * _rise_gravity * tuning.jump_height)
		floor_snap_length = 0.0 # zeroed on the jump frame so we don't snap back down
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		jumped.emit()
	elif on_floor:
		floor_snap_length = tuning.floor_snap


func _update_state(on_floor: bool) -> void:
	var new_state: State = state
	if state == State.TOSSED:
		if absf(velocity.y) < tuning.apex_hang_threshold:
			new_state = State.APEX # "regains control at apex" (carry_toss.gd)
	elif on_floor:
		new_state = State.GROUNDED
	elif absf(velocity.y) < tuning.apex_hang_threshold:
		new_state = State.APEX
	elif velocity.y > 0.0:
		new_state = State.RISING
	else:
		new_state = State.FALLING
	_set_state(new_state)


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(state)


func _update_squash_stretch(delta: float) -> void:
	if _visual == null or tuning == null:
		return
	var target: Vector3 = Vector3.ONE
	if _squash_timer > 0.0:
		_squash_timer = max(_squash_timer - delta, 0.0)
		target = tuning.squash_scale
	elif state == State.RISING:
		target = tuning.stretch_scale
	var weight: float = 1.0 - exp(-tuning.squash_spring_decay * delta)
	_visual_scale = _visual_scale.lerp(target, weight)
	_visual.scale = _visual_scale


## trigger_squash — small cosmetic pulse used by other systems (e.g. the
## carry pickup moment), reusing the same landing-squash timer/curve.
func trigger_squash() -> void:
	if tuning != null:
		_squash_timer = tuning.squash_duration


func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled


## set_virtual_input — feeds a move vector in place of real Input reads;
## used only when buddy_ai.gd is steering this body (solo mode, Otto).
func set_virtual_input(vec: Vector2) -> void:
	_virtual_input_enabled = true
	_virtual_input = vec


func clear_virtual_input() -> void:
	_virtual_input_enabled = false
	_virtual_input = Vector2.ZERO


## request_jump — buddy_ai's equivalent of a real jump press: feeds the
## same buffer/coyote gate a real button press would.
func request_jump() -> void:
	_virtual_jump_requested = true


func enter_carried() -> void:
	_enter_special_state(State.CARRIED)


func enter_bubbled() -> void:
	_enter_special_state(State.BUBBLED)


func _enter_special_state(new_state: State) -> void:
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_set_state(new_state)


## exit_special_state — restores collision (exactly layer 2 / mask 1, D7)
## and recomputes the normal state from current floor contact.
func exit_special_state() -> void:
	collision_layer = PLAYER_COLLISION_LAYER
	collision_mask = PLAYER_COLLISION_MASK
	_update_state(is_on_floor())


## launch — ballistic toss (geysers, carry_toss). No air control until apex.
func launch(velocity_override: Vector3) -> void:
	if state == State.CARRIED or state == State.BUBBLED:
		collision_layer = PLAYER_COLLISION_LAYER
		collision_mask = PLAYER_COLLISION_MASK
	velocity = velocity_override
	_set_state(State.TOSSED)
