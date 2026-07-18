class_name OrbitCameraRig
extends Node3D
## OrbitCameraRig — camera v3 (D27, Alex's first hands-on playtest note).
## ONE player per camera, full 360° orbit. Replaces the shared two-player
## CameraRig whose ±60° right-stick *nudge* made it impossible to look
## behind you, into rooms, or at doors ("couldn't look into the room on
## the map" — producer playtest, 2026-07-17). Structure is unchanged from
## the old rig: this node (position = smoothed ground-projected anchor,
## rotation.y = yaw) -> SpringArm3D (sphere-cast collision) -> Camera3D.
##
## Yaw/pitch authority, in order:
##   1. THE STICK (new): this seat's right stick orbits yaw continuously
##      (no clamp — full 360°) and pitches within [pitch_min, pitch_max].
##      While deflected, and for auto_resume_delay afterwards, every auto
##      system below is suspended. camera_manual (options) suspends them
##      permanently — stick-only, Banjo style.
##   2. CameraHint areas (unchanged) — queried at the TARGET's position
##      (not a two-player anchor); highest priority wins, blended at the
##      hint's own blend_time.
##   3. Velocity leash (unchanged math, incl. the forward-is--Z fix):
##      while the target moves, an inner leash target eases toward the
##      travel heading (leash_k) and the rig eases toward it (yaw_k).
##   4. Idle: hold. The camera never drifts on a standing player.
##
## Pitch auto (gap-read raycast) is unchanged. The frustum leash is GONE —
## in split-screen every player is always framed by their own camera, so
## there is nothing to leash (its bubble-warp was also the "teleport kept
## dropping me off the map" bug; see seat_manager.gd's ground validation).
##
## Lives under a SubViewport (CameraDirector) — get_world_3d() resolves to
## the root viewport's shared World3D, so physics queries and CameraHints
## work exactly as they did from the root tree.

@export var position_k: float = 4.0
@export var yaw_k: float = 2.0
@export var leash_k: float = 0.8
@export var pitch_k: float = 3.0

@export var arm_length: float = 6.0
@export var base_pitch_degrees: float = -32.0
@export var gap_pitch_degrees: float = -50.0

@export var vertical_dead_zone: float = 1.2
@export var leash_speed_threshold: float = 2.0

@export var pitch_probe_ahead: float = 2.0
@export var pitch_probe_height: float = 3.0
@export var gap_probe_distance: float = 6.0

@export var sphere_cast_radius: float = 0.25
@export var sphere_cast_margin: float = 0.25

## D27 — full-orbit stick. Faster than the old nudge (which only had 120°
## of travel); a full turn at default sensitivity takes ~2.4s.
@export var orbit_yaw_degrees_per_sec: float = 150.0
@export var orbit_pitch_degrees_per_sec: float = 70.0
@export var pitch_min_degrees: float = -68.0
@export var pitch_max_degrees: float = 8.0
@export var auto_resume_delay: float = 1.5
## Options-menu flag (D18, kept): true = stick-only, auto never reasserts.
@export var manual_camera: bool = false

const WORLD_GEOMETRY_MASK: int = 1
const STICK_DEAD_ZONE_SQ: float = 0.0001

var _spring_arm: SpringArm3D = null
var _camera: Camera3D = null

var _target: PlayerBody = null
var _partner: PlayerBody = null
var _seat: int = 1

var _ground_pos: Vector3 = Vector3.ZERO
var _ground_y: float = 0.0

var _anchor: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _leash_yaw: float = 0.0
var _pitch: float = 0.0

var _stick_silence: float = 999.0

var _base_orbit_yaw_speed: float = 150.0
var _base_orbit_pitch_speed: float = 70.0


## setup — call BEFORE add_child (project convention). `partner` is only
## used to exclude the other kid's body from the spring arm's sphere cast.
func setup(target: PlayerBody, partner: PlayerBody, seat: int) -> void:
	_target = target
	_partner = partner
	_seat = seat


func _ready() -> void:
	add_to_group("camera_rig")

	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "SpringArm3D"
	_spring_arm.spring_length = arm_length
	_spring_arm.margin = sphere_cast_margin
	var shape := SphereShape3D.new()
	shape.radius = sphere_cast_radius
	_spring_arm.shape = shape
	_spring_arm.collision_mask = WORLD_GEOMETRY_MASK
	add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_spring_arm.add_child(_camera)

	if _target != null:
		_spring_arm.add_excluded_object(_target.get_rid())
		_ground_pos = _target.global_position
		_ground_y = _target.global_position.y
		_anchor = _compute_anchor()
		global_position = _anchor
	if _partner != null:
		_spring_arm.add_excluded_object(_partner.get_rid())

	_pitch = deg_to_rad(base_pitch_degrees)
	_spring_arm.rotation.x = _pitch
	_yaw = rotation.y
	_leash_yaw = _yaw

	_base_orbit_yaw_speed = orbit_yaw_degrees_per_sec
	_base_orbit_pitch_speed = orbit_pitch_degrees_per_sec
	_apply_camera_settings()
	GameState.setting_changed.connect(_on_setting_changed)

	print("CAMERA_RIG_READY %s" % JSON.stringify({"seat": _seat, "orbit": true}))


func camera() -> Camera3D:
	return _camera


func _apply_camera_settings() -> void:
	var manual: Variant = GameState.get_setting("camera_manual")
	if manual != null:
		manual_camera = bool(manual)
	var sens: Variant = GameState.get_setting("camera_sensitivity")
	if sens != null:
		var scale_factor: float = clampf(float(sens), 0.25, 2.0)
		orbit_yaw_degrees_per_sec = _base_orbit_yaw_speed * scale_factor
		orbit_pitch_degrees_per_sec = _base_orbit_pitch_speed * scale_factor


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key.begins_with("camera_"):
		_apply_camera_settings()


func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return

	_update_ground_tracking()

	var pos_weight: float = 1.0 - exp(-position_k * delta)
	_anchor = _anchor.lerp(_compute_anchor(), pos_weight)
	global_position = _anchor

	var stick: Vector2 = _read_stick()
	if stick.length_squared() > STICK_DEAD_ZONE_SQ:
		_stick_silence = 0.0
		_yaw -= deg_to_rad(orbit_yaw_degrees_per_sec) * stick.x * delta
		_yaw = wrapf(_yaw, -PI, PI)
		# Stick-up = negative y (p1_move_up axis convention) -> negate so up
		# tilts the camera up (less-downward pitch), never inverted.
		_pitch = clampf(
			_pitch + deg_to_rad(orbit_pitch_degrees_per_sec) * -stick.y * delta,
			deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees)
		)
		# Keep the leash target in step so auto-resume never snaps backward.
		_leash_yaw = _yaw
	else:
		_stick_silence += delta
		if not manual_camera and _stick_silence >= auto_resume_delay:
			_update_auto_yaw(delta)
			_update_auto_pitch(delta)

	rotation.y = _yaw
	_spring_arm.rotation.x = _pitch


func _update_ground_tracking() -> void:
	if _target.is_on_floor():
		_ground_pos.x = _target.global_position.x
		_ground_pos.z = _target.global_position.z
	var actual_y: float = _target.global_position.y
	if absf(actual_y - _ground_y) > vertical_dead_zone:
		if actual_y > _ground_y:
			_ground_y = actual_y - vertical_dead_zone
		else:
			_ground_y = actual_y + vertical_dead_zone


func _compute_anchor() -> Vector3:
	return Vector3(_ground_pos.x, _ground_y, _ground_pos.z)


func _read_stick() -> Vector2:
	return Input.get_vector(
		"p%d_camera_left" % _seat, "p%d_camera_right" % _seat,
		"p%d_camera_up" % _seat, "p%d_camera_down" % _seat
	)


func _update_auto_yaw(delta: float) -> void:
	var hint: Node = _find_active_hint(_anchor)
	if hint != null:
		# Object.get() not typed access — Godot 4.6.2 headless bug resolving
		# external class_name members on runtime-obtained values (see the old
		# camera_rig.gd's identical note + worlds/_scratch_test repro).
		var yaw_degrees: float = hint.get("yaw_degrees")
		var blend_time: float = hint.get("blend_time")
		var rate: float = 1.0 / maxf(blend_time, 0.001)
		_yaw = lerp_angle(_yaw, deg_to_rad(yaw_degrees), 1.0 - exp(-rate * delta))
		_leash_yaw = _yaw
		return
	var horizontal_vel: Vector3 = Vector3(_target.velocity.x, 0.0, _target.velocity.z)
	if horizontal_vel.length() > leash_speed_threshold:
		# Camera forward is -Z rotated by yaw: facing the travel direction
		# needs atan2(-vx, -vz); atan2(vx, vz) is exactly pi off (the old
		# rig's players trailed facing BACKWARD — fixed analytically, D25).
		var heading: float = atan2(-horizontal_vel.x, -horizontal_vel.z)
		_leash_yaw = lerp_angle(_leash_yaw, heading, 1.0 - exp(-leash_k * delta))
	_yaw = lerp_angle(_yaw, _leash_yaw, 1.0 - exp(-yaw_k * delta))


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


func _update_auto_pitch(delta: float) -> void:
	var target_pitch_deg: float = base_pitch_degrees
	if not _has_ground_ahead():
		target_pitch_deg = gap_pitch_degrees
	_pitch = lerp_angle(_pitch, deg_to_rad(target_pitch_deg), 1.0 - exp(-pitch_k * delta))


func _has_ground_ahead() -> bool:
	var forward: Vector3 = _target_facing_direction()
	var origin: Vector3 = _target.global_position + forward * pitch_probe_ahead + Vector3.UP * pitch_probe_height
	var end: Vector3 = origin + Vector3.DOWN * (gap_probe_distance + pitch_probe_height)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = WORLD_GEOMETRY_MASK
	return not space_state.intersect_ray(query).is_empty()


func _target_facing_direction() -> Vector3:
	var visual: Node3D = _target.get_node_or_null("Visual") as Node3D
	if visual == null:
		return Vector3.FORWARD
	var yaw: float = visual.rotation.y
	return Vector3(sin(yaw), 0.0, cos(yaw))
