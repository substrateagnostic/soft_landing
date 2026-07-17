class_name CameraRig
extends Node3D
## CameraRig — SPEC.md core/camera/camera_rig.gd (D4/D5). Fully automatic
## third-person camera; auto by default (D18 — right stick is never
## required, GOAL.md floor) with a small additive right-stick yaw/pitch
## nudge layered on top (see the D18 note below _update_yaw/_update_pitch).
## Structure: this node (position = smoothed ground-projected anchor,
## rotation.y = yaw) -> SpringArm3D (sphere-cast collision backbone,
## rotation.x = pitch) -> Camera3D.
##
## Anchor: 0.7*Pip + 0.3*Otto ground-projected position (solo: 1.0*Pip),
## each with an independent vertical dead zone so routine hops don't move
## the camera. Position smoothing is exponential decay (1-exp(-k*delta)).
##
## Yaw: CameraHint areas overlapping the anchor win by priority, blended at
## a rate derived from hint.blend_time; with no hint active, a heavily
## damped velocity-leash eases an inner target toward Pip's horizontal
## velocity heading (leash_k) and the rig's own yaw eases toward that
## target (yaw_k) — two damping stages so a mashed stick never whips the
## camera or jitters while circling.
##
## Pitch: raycasts down ahead of Pip; no ground within gap_probe_distance
## eases pitch toward gap_pitch_degrees (reading the gap).
##
## Co-op leash: either player drifting outside the frustum by more than
## frustum_margin for longer than frustum_leash_time emits leash_broken —
## SeatManager consumes it and bubble-warps the stray player back.
##
## D18: right stick (either seat, summed) gently nudges a yaw/pitch offset
## layered ON TOP of the auto yaw/pitch computed above — CameraHints and the
## velocity leash keep steering the base _yaw/_pitch exactly as before, the
## nudge just rides along on top, so a hint still "wins" (blend, not fight).
## After camera_recenter_delay seconds of stick silence the offset eases
## back to zero, unless manual_camera is set (an options-menu flag for a
## future full-manual mode) in which case the nudge holds indefinitely.
## Right stick is never required (GOAL.md floor) — every other yaw/pitch
## system above already works with zero right-stick input.

signal leash_broken(player: PlayerBody)

@export var position_k: float = 4.0
@export var yaw_k: float = 2.0
@export var leash_k: float = 0.8
@export var pitch_k: float = 3.0

@export var arm_length: float = 6.0
@export var base_pitch_degrees: float = -32.0
@export var gap_pitch_degrees: float = -50.0

@export var vertical_dead_zone: float = 1.2
@export var pip_weight_coop: float = 0.7
@export var otto_weight_coop: float = 0.3

@export var leash_speed_threshold: float = 2.0

@export var pitch_probe_ahead: float = 2.0
@export var pitch_probe_height: float = 3.0
@export var gap_probe_distance: float = 6.0

@export var frustum_margin: float = 2.0
@export var frustum_leash_time: float = 1.5

@export var sphere_cast_radius: float = 0.25
@export var sphere_cast_margin: float = 0.25

## D18 — right-stick nudge (gentle, never required; see class doc).
@export var camera_nudge_yaw_degrees_per_sec: float = 90.0
@export var camera_nudge_pitch_degrees_per_sec: float = 40.0
@export var camera_nudge_max_yaw_degrees: float = 60.0
@export var camera_nudge_max_pitch_degrees: float = 20.0
@export var camera_recenter_delay: float = 1.5
@export var camera_recenter_k: float = 2.0
## Options-menu hook: true disables auto-recenter so a nudge holds until
## the player nudges it back (full-manual yaw/pitch offset).
@export var manual_camera: bool = false

const WORLD_GEOMETRY_MASK: int = 1

@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D

var _pip: PlayerBody = null
var _otto: PlayerBody = null
var _solo: bool = false

var _pip_ground_pos: Vector3 = Vector3.ZERO
var _otto_ground_pos: Vector3 = Vector3.ZERO
var _pip_ground_y: float = 0.0
var _otto_ground_y: float = 0.0

var _anchor: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _leash_yaw: float = 0.0
var _pitch: float = 0.0

var _pip_outside_time: float = 0.0
var _otto_outside_time: float = 0.0

var _manual_yaw_offset: float = 0.0
var _manual_pitch_offset: float = 0.0
var _nudge_silence_timer: float = 0.0


func _ready() -> void:
	add_to_group("camera_rig")

	_spring_arm.spring_length = arm_length
	_spring_arm.margin = sphere_cast_margin
	var shape := SphereShape3D.new()
	shape.radius = sphere_cast_radius
	_spring_arm.shape = shape
	_spring_arm.collision_mask = WORLD_GEOMETRY_MASK

	_pitch = deg_to_rad(base_pitch_degrees)
	_spring_arm.rotation.x = _pitch
	_yaw = rotation.y
	_leash_yaw = _yaw

	# D18 options wiring: the pause menu persists camera_manual /
	# camera_sensitivity through GameState.settings; the rig applies them
	# live. Base speeds captured once so sensitivity scales, not compounds.
	_base_nudge_yaw_speed = camera_nudge_yaw_degrees_per_sec
	_base_nudge_pitch_speed = camera_nudge_pitch_degrees_per_sec
	_apply_camera_settings()
	GameState.setting_changed.connect(_on_setting_changed)

	print("CAMERA_RIG_READY")


var _base_nudge_yaw_speed: float = 90.0
var _base_nudge_pitch_speed: float = 40.0


func _apply_camera_settings() -> void:
	var manual: Variant = GameState.get_setting("camera_manual")
	if manual != null:
		manual_camera = bool(manual)
	var sens: Variant = GameState.get_setting("camera_sensitivity")
	if sens != null:
		var scale_factor: float = clampf(float(sens), 0.25, 2.0)
		camera_nudge_yaw_degrees_per_sec = _base_nudge_yaw_speed * scale_factor
		camera_nudge_pitch_degrees_per_sec = _base_nudge_pitch_speed * scale_factor


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key.begins_with("camera_"):
		_apply_camera_settings()


## register_players — call once after both bodies exist in the tree.
func register_players(pip: PlayerBody, otto: PlayerBody) -> void:
	_pip = pip
	_otto = otto
	if pip != null:
		_spring_arm.add_excluded_object(pip.get_rid())
		_pip_ground_pos = pip.global_position
		_pip_ground_y = pip.global_position.y
	if otto != null:
		_spring_arm.add_excluded_object(otto.get_rid())
		_otto_ground_pos = otto.global_position
		_otto_ground_y = otto.global_position.y
	_anchor = _compute_anchor()
	global_position = _anchor


func set_solo(solo: bool) -> void:
	_solo = solo


func _physics_process(delta: float) -> void:
	if _pip == null:
		return

	_update_ground_tracking(_pip, true)
	if _otto != null:
		_update_ground_tracking(_otto, false)

	var target_anchor: Vector3 = _compute_anchor()
	var pos_weight: float = 1.0 - exp(-position_k * delta)
	_anchor = _anchor.lerp(target_anchor, pos_weight)
	global_position = _anchor

	_update_camera_nudge(delta)
	_update_yaw(delta)
	_update_pitch(delta)
	_update_frustum_leash(delta)


func _update_ground_tracking(player: PlayerBody, is_pip: bool) -> void:
	if player.is_on_floor():
		var pos: Vector3 = player.global_position
		if is_pip:
			_pip_ground_pos.x = pos.x
			_pip_ground_pos.z = pos.z
		else:
			_otto_ground_pos.x = pos.x
			_otto_ground_pos.z = pos.z

	var actual_y: float = player.global_position.y
	if is_pip:
		_pip_ground_y = _apply_vertical_dead_zone(actual_y, _pip_ground_y)
	else:
		_otto_ground_y = _apply_vertical_dead_zone(actual_y, _otto_ground_y)


func _apply_vertical_dead_zone(actual_y: float, tracked_y: float) -> float:
	if absf(actual_y - tracked_y) <= vertical_dead_zone:
		return tracked_y
	if actual_y > tracked_y:
		return actual_y - vertical_dead_zone
	return actual_y + vertical_dead_zone


func _compute_anchor() -> Vector3:
	var pip_pos: Vector3 = Vector3(_pip_ground_pos.x, _pip_ground_y, _pip_ground_pos.z)
	if _solo or _otto == null:
		return pip_pos
	var otto_pos: Vector3 = Vector3(_otto_ground_pos.x, _otto_ground_y, _otto_ground_pos.z)
	return pip_pos * pip_weight_coop + otto_pos * otto_weight_coop


func _update_yaw(delta: float) -> void:
	var hint: Node = _find_active_hint(_anchor)
	if hint != null:
		# NOTE: read via Object.get() (dynamic), not typed member access —
		# Godot 4.6.2 headless GDScript has a reproducible bug resolving
		# instance members of an externally-`class_name`'d script accessed
		# through a value obtained at runtime (physics query / .new()) in a
		## --headless (non-editor) run: "Could not resolve external class
		# member". Confirmed independently by the worlds-agent's own repro
		# in worlds/_scratch_test/ (same failure on a minimal throwaway
		# class). Object.get() is a plain runtime property lookup and
		# sidesteps the static-resolution path entirely.
		var yaw_degrees: float = hint.get("yaw_degrees")
		var blend_time: float = hint.get("blend_time")
		var target_yaw: float = deg_to_rad(yaw_degrees)
		var rate: float = 1.0 / maxf(blend_time, 0.001)
		_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-rate * delta))
	elif _pip != null:
		var horizontal_vel: Vector3 = Vector3(_pip.velocity.x, 0.0, _pip.velocity.z)
		if horizontal_vel.length() > leash_speed_threshold:
			# Camera forward is -Z rotated by yaw: forward = (-sin y, -cos y).
			# Facing the TRAVEL direction therefore needs atan2(-vx, -vz);
			# atan2(vx, vz) is exactly pi off — the camera trailed players
			# facing BACKWARD whenever no CameraHint covered them (found on
			# the D25 ascent, where hints have gaps; confirmed analytically).
			var heading: float = atan2(-horizontal_vel.x, -horizontal_vel.z)
			_leash_yaw = lerp_angle(_leash_yaw, heading, 1.0 - exp(-leash_k * delta))
		# else: hold — heavily damped, no jitter when circling or idle
		_yaw = lerp_angle(_yaw, _leash_yaw, 1.0 - exp(-yaw_k * delta))
	rotation.y = _yaw + _manual_yaw_offset # D18: hint/leash still own the base yaw; nudge rides on top


func _find_active_hint(point: Vector3) -> Node:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var params := PhysicsPointQueryParameters3D.new()
	params.position = point
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = CameraHint.HINT_COLLISION_LAYER
	var results: Array[Dictionary] = space_state.intersect_point(params, 8)
	var best: Node = null
	var best_priority: int = -2147483648
	for result: Dictionary in results:
		var collider: Object = result.get("collider")
		if not (collider is CameraHint):
			continue
		var p: int = collider.get("priority")
		if best == null or p > best_priority:
			best = collider
			best_priority = p
	return best


func _update_pitch(delta: float) -> void:
	var target_pitch_deg: float = base_pitch_degrees
	if _pip != null and not _has_ground_ahead():
		target_pitch_deg = gap_pitch_degrees
	var target_pitch: float = deg_to_rad(target_pitch_deg)
	_pitch = lerp_angle(_pitch, target_pitch, 1.0 - exp(-pitch_k * delta))
	var clamped_pitch_offset: float = clampf(
		_manual_pitch_offset, -deg_to_rad(camera_nudge_max_pitch_degrees), deg_to_rad(camera_nudge_max_pitch_degrees)
	)
	_spring_arm.rotation.x = _pitch + clamped_pitch_offset


func _has_ground_ahead() -> bool:
	var forward: Vector3 = _pip_facing_direction()
	var origin: Vector3 = _pip.global_position + forward * pitch_probe_ahead + Vector3.UP * pitch_probe_height
	var end: Vector3 = origin + Vector3.DOWN * (gap_probe_distance + pitch_probe_height)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = WORLD_GEOMETRY_MASK
	var result: Dictionary = space_state.intersect_ray(query)
	return not result.is_empty()


func _pip_facing_direction() -> Vector3:
	var visual: Node3D = _pip.get_node_or_null("Visual") as Node3D
	if visual == null:
		return Vector3.FORWARD
	var yaw: float = visual.rotation.y
	return Vector3(sin(yaw), 0.0, cos(yaw))


## _update_camera_nudge — D18. Accumulates a yaw/pitch offset from whichever
## seat's right stick is deflected (summed, clamped) and eases it back to
## zero after camera_recenter_delay seconds of silence, unless manual_camera
## is set. Entirely additive: _update_yaw()/_update_pitch() still compute
## the "preferred" base yaw/pitch exactly as before (hints, velocity leash,
## gap-read pitch) with this offset layered on top.
func _update_camera_nudge(delta: float) -> void:
	var stick: Vector2 = _read_camera_stick()
	if stick.length_squared() > 0.0001:
		_nudge_silence_timer = 0.0
		_manual_yaw_offset = clampf(
			_manual_yaw_offset + deg_to_rad(camera_nudge_yaw_degrees_per_sec) * stick.x * delta,
			-deg_to_rad(camera_nudge_max_yaw_degrees), deg_to_rad(camera_nudge_max_yaw_degrees)
		)
		# Stick up == negative y (matches p1_move_up's axis_value convention) -> negate so
		# pushing up tilts the camera up (less-downward pitch), never inverted.
		_manual_pitch_offset = clampf(
			_manual_pitch_offset + deg_to_rad(camera_nudge_pitch_degrees_per_sec) * -stick.y * delta,
			-deg_to_rad(camera_nudge_max_pitch_degrees), deg_to_rad(camera_nudge_max_pitch_degrees)
		)
		return
	_nudge_silence_timer += delta
	if manual_camera or _nudge_silence_timer < camera_recenter_delay:
		return
	var weight: float = 1.0 - exp(-camera_recenter_k * delta)
	_manual_yaw_offset = lerp(_manual_yaw_offset, 0.0, weight)
	_manual_pitch_offset = lerp(_manual_pitch_offset, 0.0, weight)


## _read_camera_stick — both seats' right sticks, summed and clamped to unit
## length so co-op nudging from either (or both) players feels consistent
## with a single stick's max deflection. Never required (GOAL.md floor):
## returns ZERO with no controller connected or the right stick untouched.
func _read_camera_stick() -> Vector2:
	var p1: Vector2 = Input.get_vector("p1_camera_left", "p1_camera_right", "p1_camera_up", "p1_camera_down")
	var p2: Vector2 = Input.get_vector("p2_camera_left", "p2_camera_right", "p2_camera_up", "p2_camera_down")
	return (p1 + p2).limit_length(1.0)


func _update_frustum_leash(delta: float) -> void:
	if _solo or _otto == null:
		_pip_outside_time = 0.0
		_otto_outside_time = 0.0
		return

	_pip_outside_time = _accumulate_outside_time(_pip, _pip_outside_time, delta)
	_otto_outside_time = _accumulate_outside_time(_otto, _otto_outside_time, delta)

	if _pip_outside_time > frustum_leash_time:
		_pip_outside_time = 0.0
		leash_broken.emit(_pip)
	if _otto_outside_time > frustum_leash_time:
		_otto_outside_time = 0.0
		leash_broken.emit(_otto)


func _accumulate_outside_time(player: PlayerBody, current: float, delta: float) -> float:
	if _is_outside_frustum_by_margin(player.global_position, frustum_margin):
		return current + delta
	return 0.0


## _is_outside_frustum_by_margin — Camera3D.get_frustum() returns planes
## with outward-facing normals (Godot convention); a point is outside a
## plane by plane.distance_to(point) when that value is positive. The worst
## (largest) violation across all planes is how far outside the point is.
func _is_outside_frustum_by_margin(point: Vector3, margin: float) -> bool:
	var planes: Array[Plane] = _camera.get_frustum()
	var max_violation: float = -INF
	for plane: Plane in planes:
		max_violation = max(max_violation, plane.distance_to(point))
	return max_violation > margin
