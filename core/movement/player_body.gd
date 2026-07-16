class_name PlayerBody
extends CharacterBody3D
## PlayerBody — shared movement core for Pip and Otto (SPEC.md). Every feel
## number lives in `tuning` (a MovementTuning resource); this script holds
## no magic numbers. This is the CORRECT BASIC version the core-feel agent
## extends (not rewrites): horizontal accel/decel, derived gravity (rise vs
## fall via fall_gravity_mult), fixed jump height with coyote time + jump
## buffer, is_on_floor() read after move_and_slide(), lerp_angle mesh
## turning of the child "Visual" node. Apex-hang/carried/tossed/bubbled
## states are reserved for the core-feel agent's extension.

signal jumped
signal landed

@export var seat: int = 1
@export var tuning: MovementTuning

@onready var _visual: Node3D = get_node_or_null("Visual") as Node3D

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _rise_gravity: float = 0.0
var _fall_gravity: float = 0.0

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

	if tuning != null:
		# h = 1/2 * g * t^2 at apex, v0 = g*t -> g = 2h/t^2. Gravity is
		# always derived from jump_height/time_to_apex, never hand-set (D3).
		_rise_gravity = (2.0 * tuning.jump_height) / (tuning.time_to_apex * tuning.time_to_apex)
		_fall_gravity = _rise_gravity * tuning.fall_gravity_mult
		floor_snap_length = tuning.floor_snap


func _physics_process(delta: float) -> void:
	if tuning == null:
		return

	var was_on_floor: bool = is_on_floor()

	if was_on_floor:
		_coyote_timer = tuning.coyote_time
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	_apply_gravity(was_on_floor, delta)
	_apply_horizontal_movement(was_on_floor, delta)
	_update_jump_buffer(delta)
	_try_jump(was_on_floor) # may zero _coyote_timer if it consumes the jump this frame

	move_and_slide()

	if is_on_floor() and not was_on_floor:
		landed.emit()


func _apply_gravity(on_floor: bool, delta: float) -> void:
	if on_floor:
		return
	var gravity: float = _rise_gravity if velocity.y > 0.0 else _fall_gravity
	velocity.y = max(velocity.y - gravity * delta, -tuning.terminal_velocity)


func _apply_horizontal_movement(on_floor: bool, delta: float) -> void:
	var input_vec: Vector2 = Input.get_vector(
		_move_action_left, _move_action_right, _move_action_up, _move_action_down
	)
	var move_dir: Vector3 = Vector3(input_vec.x, 0.0, input_vec.y)
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


func _update_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed(_jump_action):
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
