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
##
## D17 moveset ladder adds three ceiling verbs, riding the existing
## jump/interact buttons only (no new input floor, per GOAL.md):
##   FLUTTER — tap jump again while airborne: one small extra boost per
##   airtime (re-arms continuously while grounded, and explicitly on
##   carry/rescue exit). Buffered exactly like the ground jump. Works out of
##   a GLIDE too (a flap that also cancels the glide).
##   GLIDE — hold jump while falling: reduced gravity + a slow fall-speed
##   cap + a little extra air control, for as long as jump stays held.
##   Releasing, landing, or entering CARRIED/TOSSED/BUBBLED ends it.
##   POUND — tap interact while airborne (never while carrying/carried/
##   tossed — carry_toss.gd is the sole owner of both interact buttons and
##   only falls through to try_pound() when its own carry/toss logic
##   doesn't apply, so the two verbs can never race on the same press): a
##   brief hang, then a fast committed drop. Landing fires `pound_landed`
##   and gives every OTHER grounded player within `pound_radius` a free
##   launch (`receive_pound_launch()`) — a gift, never a knockback, never
##   punitive.
## All three verbs are ceiling only: nothing in any world may require them,
## and CARRIED/TOSSED/BUBBLED suppress all three (D17 "rules of the floor").

signal jumped
signal landed
signal state_changed(new_state: int)
signal pound_landed(position: Vector3) ## D17 — hook for future juice (particles, camera shake); no listener yet.

enum State { GROUNDED, RISING, APEX, FALLING, CARRIED, TOSSED, BUBBLED, FLUTTER, GLIDE, POUND }
enum PoundPhase { HANG, DROP }

const PLAYER_COLLISION_LAYER: int = 2 # D7: both kids share this layer
const PLAYER_COLLISION_MASK: int = 1 # world geometry only -> no player-player collision

@export var seat: int = 1
@export var tuning: MovementTuning

@onready var _visual: Node3D = get_node_or_null("Visual") as Node3D

var state: State = State.GROUNDED

## D27 split-screen: the camera THIS seat steers relative to, assigned by
## CameraDirector (each kid's own half). Falls back to the viewport camera
## when unset (solo fallback paths, harness scenes without a director).
var control_camera: Camera3D = null

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _virtual_jump_requested: bool = false
var _rise_gravity: float = 0.0
var _fall_gravity: float = 0.0

var _flutter_used: bool = false # once per airtime; re-armed continuously while grounded (D17)
var _flutter_timer: float = 0.0 # counts down the brief FLUTTER animation-hook window

var _pound_phase: PoundPhase = PoundPhase.HANG
var _pound_timer: float = 0.0

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
	add_to_group("players") # dreamling magnetism, harness tracking
	var prefix: String = "p%d_" % seat
	_move_action_left = prefix + "move_left"
	_move_action_right = prefix + "move_right"
	_move_action_up = prefix + "move_up"
	_move_action_down = prefix + "move_down"
	_jump_action = prefix + "jump"

	floor_constant_speed = true
	# D17 moving-platform audit: ADD_VELOCITY (not ADD_UPWARD_VELOCITY)
	# inherits a platform's full momentum on jump-off, not just its
	# vertical component -- behaviorally identical to the old setting for
	# bramble's currently vertical-only BreathingChest (worlds/**, read-only
	# to this agent), but correct for any future horizontally moving
	# platform. platform_floor_layers set explicitly (all layers) so
	# velocity inheritance is never silently gated by an engine default.
	platform_on_leave = PLATFORM_ON_LEAVE_ADD_VELOCITY
	platform_floor_layers = 0xFFFFFFFF
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
		_flutter_used = false # continuous re-arm while grounded (D17)
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)
	_flutter_timer = max(_flutter_timer - delta, 0.0)

	var jump_held: bool = _is_jump_held()
	var ballistic: bool = state == State.TOSSED or state == State.POUND

	# Buffer + jump/flutter resolution runs FIRST, before glide-entry is even
	# considered: a ground/coyote jump or a flutter both hard-SET velocity.y
	# positive, so _maybe_start_glide's own velocity.y >= 0.0 guard then
	# naturally refuses to start a glide on the very same tick a jump just
	# fired — no separate "was this a fresh press" bookkeeping needed.
	if not ballistic:
		_update_jump_buffer(delta)
		_try_jump(was_on_floor) # may zero _coyote_timer if it consumes the jump this frame

	_maybe_start_glide(jump_held, was_on_floor)

	if state == State.POUND:
		_process_pound(delta)
	else:
		_apply_gravity(was_on_floor, delta, jump_held)

	if not ballistic:
		_apply_horizontal_movement(was_on_floor, delta)

	move_and_slide()

	var on_floor_now: bool = is_on_floor()
	if on_floor_now and not was_on_floor:
		if state == State.POUND:
			_land_pound() # fires pound_landed + the partner shockwave before the generic landed below
		landed.emit()
		_squash_timer = tuning.squash_duration

	_update_state(on_floor_now)
	_update_squash_stretch(delta)


func _apply_gravity(on_floor: bool, delta: float, jump_held: bool) -> void:
	if on_floor:
		return
	if state == State.GLIDE:
		if not jump_held:
			_set_state(State.FALLING) # releasing jump ends the glide immediately, same frame
		else:
			var glide_gravity: float = _fall_gravity * tuning.glide_gravity_mult
			velocity.y = max(velocity.y - glide_gravity * delta, -tuning.glide_terminal_velocity)
			return
	var gravity: float = _rise_gravity if velocity.y > 0.0 else _fall_gravity
	if state == State.APEX:
		gravity *= tuning.apex_gravity_mult # the flutter window
	velocity.y = max(velocity.y - gravity * delta, -tuning.terminal_velocity)


## _is_jump_held — real Input.is_action_pressed for the owning seat; never
## true for buddy_ai's virtual-input Otto (D17 "skip if fragile": buddy AI
## does not glide, only mirrors jumps via request_jump()).
func _is_jump_held() -> bool:
	if _virtual_input_enabled or not _control_enabled:
		return false
	return Input.is_action_pressed(_jump_action)


## _maybe_start_glide — entry only; continuation and release-exit are both
## handled inline in _apply_gravity() so a released button ends the glide
## on the very same frame it's released. Runs AFTER this frame's jump-buffer
## resolution (see _physics_process), so velocity.y >= 0.0 already guards
## against preempting a jump/flutter that just fired this same tick — a
## press-and-hold gesture while already falling without coyote resolves as
## a flutter (via _try_jump, which runs first) and never spuriously starts
## a glide first.
func _maybe_start_glide(jump_held: bool, on_floor: bool) -> void:
	if on_floor or state == State.GLIDE or not jump_held or velocity.y >= 0.0:
		return
	if state == State.RISING or state == State.APEX or state == State.FALLING or state == State.FLUTTER:
		_set_state(State.GLIDE)
		print("GLIDE_START %s" % JSON.stringify({"seat": seat}))


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
	if state == State.GLIDE:
		control = tuning.air_control * tuning.glide_air_control_mult # D17: slight forward air-control boost
	var rate: float = (tuning.accel if move_dir.length_squared() > 0.0 else tuning.decel) * control

	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if _visual != null and move_dir.length_squared() > 0.001:
		var target_yaw: float = atan2(move_dir.x, move_dir.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, tuning.turn_speed * delta)


func _camera_relative_dir(input_vec: Vector2) -> Vector3:
	var camera: Camera3D = control_camera if is_instance_valid(control_camera) else null
	if camera == null:
		camera = get_viewport().get_camera_3d() if get_viewport() != null else null
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


## _try_jump — a buffered press first tries a normal ground/coyote jump;
## if neither is available it falls through to the flutter (D17), buffered
## exactly the same way, so a tap that arrives a frame early or late is
## just as forgiving for the second jump as it is for the first.
func _try_jump(on_floor: bool) -> void:
	var can_ground_jump: bool = on_floor or _coyote_timer > 0.0
	if _jump_buffer_timer > 0.0 and can_ground_jump:
		velocity.y = sqrt(2.0 * _rise_gravity * tuning.jump_height)
		floor_snap_length = 0.0 # zeroed on the jump frame so we don't snap back down
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		jumped.emit()
	elif _jump_buffer_timer > 0.0 and not _flutter_used and _flutter_eligible():
		_trigger_flutter()
		_jump_buffer_timer = 0.0
	elif on_floor:
		floor_snap_length = tuning.floor_snap


func _flutter_eligible() -> bool:
	return state == State.RISING or state == State.APEX or state == State.FALLING or state == State.GLIDE


func _trigger_flutter() -> void:
	_flutter_used = true
	velocity.y = sqrt(2.0 * _rise_gravity * tuning.jump_height * tuning.flutter_height_mult)
	_flutter_timer = tuning.flutter_duration
	_set_state(State.FLUTTER)
	print("FLUTTER %s" % JSON.stringify({"seat": seat}))


func _update_state(on_floor: bool) -> void:
	var new_state: State = state
	if state == State.TOSSED:
		if absf(velocity.y) < tuning.apex_hang_threshold:
			new_state = State.APEX # "regains control at apex" (carry_toss.gd)
	elif state == State.POUND:
		pass # committed dive; the landing transition is handled explicitly by _land_pound()
	elif state == State.GLIDE:
		if on_floor:
			new_state = State.GROUNDED
		# else: stays GLIDE — continuation/release-exit already resolved in _apply_gravity()
	elif state == State.FLUTTER:
		if on_floor:
			new_state = State.GROUNDED
		elif _flutter_timer <= 0.0:
			new_state = _classify_airborne()
		# else: stays FLUTTER for the remainder of flutter_duration (animation-hook window)
	elif on_floor:
		new_state = State.GROUNDED
	else:
		new_state = _classify_airborne()
	_set_state(new_state)


func _classify_airborne() -> State:
	if absf(velocity.y) < tuning.apex_hang_threshold:
		return State.APEX
	elif velocity.y > 0.0:
		return State.RISING
	else:
		return State.FALLING


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
## and recomputes the normal state from current floor contact. Also resets
## the flutter charge (D17 "reset on ground/rescue/carry") so control
## returning mid-air (a rescue pop, a hop-down over a drop) always comes
## back with a fresh flutter, not a stale used-up one from before.
func exit_special_state() -> void:
	collision_layer = PLAYER_COLLISION_LAYER
	collision_mask = PLAYER_COLLISION_MASK
	_flutter_used = false
	_update_state(is_on_floor())


## launch — ballistic toss (geysers, carry_toss). No air control until apex.
func launch(velocity_override: Vector3) -> void:
	if state == State.CARRIED or state == State.BUBBLED:
		collision_layer = PLAYER_COLLISION_LAYER
		collision_mask = PLAYER_COLLISION_MASK
	velocity = velocity_override
	_flutter_used = false # D17: a toss is a fresh airtime — flutter is available at its apex
	_set_state(State.TOSSED)


# ---------------------------------------------------------------------------
# D17 — ground-pound bounce (co-op verb; trigger routed exclusively through
# carry_toss.gd so the two interact-button verbs can never race — see the
# class doc comment above).
# ---------------------------------------------------------------------------

## try_pound — the sole entry point into POUND. Returns false (no-op) if
## this player isn't in a plain airborne state (excludes CARRIED, BUBBLED,
## TOSSED, and POUND itself, satisfying "not carrying/carried").
func try_pound() -> bool:
	if tuning == null:
		return false
	if not (state == State.RISING or state == State.APEX or state == State.FALLING
			or state == State.FLUTTER or state == State.GLIDE):
		return false
	_pound_phase = PoundPhase.HANG
	_pound_timer = tuning.pound_hang_duration
	velocity = Vector3.ZERO
	_set_state(State.POUND)
	print("POUND_START %s" % JSON.stringify({"seat": seat}))
	return true


func _process_pound(delta: float) -> void:
	match _pound_phase:
		PoundPhase.HANG:
			velocity = Vector3.ZERO
			_pound_timer = max(_pound_timer - delta, 0.0)
			if _pound_timer <= 0.0:
				_pound_phase = PoundPhase.DROP
		PoundPhase.DROP:
			velocity.x = 0.0
			velocity.z = 0.0
			velocity.y = -tuning.pound_drop_speed


func _land_pound() -> void:
	_set_state(State.GROUNDED)
	pound_landed.emit(global_position)
	print("POUND_LAND %s" % JSON.stringify({"seat": seat}))
	_apply_pound_shockwave()


## _apply_pound_shockwave — every OTHER grounded, non-special-state player
## within tuning.pound_radius gets a free launch. Pure gift: no damage, no
## knockback, launcher included (self is skipped, never launches itself).
func _apply_pound_shockwave() -> void:
	var pos: Vector3 = global_position
	for node: Node in get_tree().get_nodes_in_group("players"):
		var other: PlayerBody = node as PlayerBody
		if other == null or other == self:
			continue
		if other.state == State.CARRIED or other.state == State.BUBBLED or other.state == State.TOSSED:
			continue
		if not other.is_on_floor():
			continue
		if pos.distance_to(other.global_position) > tuning.pound_radius:
			continue
		other.receive_pound_launch()


## receive_pound_launch — called by ANOTHER PlayerBody's shockwave. Sets a
## clean upward velocity for tuning.jump_height * tuning.pound_launch_mult
## (same derived-gravity math as a normal jump, D3), and resets this
## player's own coyote/flutter/buffer so the gift is a completely fresh
## airtime, not a fall-through of whatever state they were just in.
func receive_pound_launch() -> void:
	if tuning == null:
		return
	velocity.y = sqrt(2.0 * _rise_gravity * tuning.jump_height * tuning.pound_launch_mult)
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_flutter_used = false
	floor_snap_length = 0.0 # matches _try_jump's own jump-frame handling — don't snap back down
	_set_state(State.RISING)
