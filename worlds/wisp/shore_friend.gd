class_name ShoreFriend
extends Node3D
## ShoreFriend — D28 (producer, night two: "starfish and penguins were the
## winners" at the Shedd Aquarium that afternoon). The penguin chick who
## waddles Wisp's shore. Behavior tuned to how the real ones behaved at
## the glass: it does NOT flee — when a kid comes close it stops, turns to
## face them, and does two excited little bounces (with a soft squeak),
## then waddles on. Movement is a slow patrol between two authored points
## with a side-to-side waddle rock and an occasional tiny hop.
##
## Visual: grey capsule + white belly placeholder, replaced by the plush
## GLB via ModelSlot (penguin_chick_plush, 0.55 m) the moment the import
## lands — the D10 anchor convention (this node IS the ground anchor).
## setup() before add_child (established repo convention).

const WADDLE_SPEED: float = 0.7
const WADDLE_ROCK_DEG: float = 8.0
const WADDLE_ROCK_HZ: float = 2.2
const HOP_INTERVAL: float = 4.5 # average seconds between idle hops
const HOP_HEIGHT: float = 0.14
const GREET_RADIUS: float = 2.2
const GREET_COOLDOWN: float = 6.0
const GREET_BOUNCES: int = 2
const TURN_SPEED: float = 5.0

var _point_a: Vector3 = Vector3.ZERO
var _point_b: Vector3 = Vector3.ZERO
var _toward_b: bool = true
var _visual: Node3D = null
var _rock_time: float = 0.0
var _hop_timer: float = 3.0
var _hop_phase: float = -1.0 # <0 = not hopping
var _greet_cooldown: float = 0.0
var _greeting: float = -1.0 # <0 = not greeting; else greet elapsed


## setup — patrol endpoints in world space (already terrain-snapped by the
## caller; this node lerps y between them as it walks).
func setup(point_a: Vector3, point_b: Vector3) -> void:
	_point_a = point_a
	_point_b = point_b


func _ready() -> void:
	global_position = _point_a
	_build_placeholder()

	# Under Visual, NOT the root: ModelSlot hides only DIRECT MeshInstance3D
	# siblings, and the GLB must ride Visual's hop/rock animation.
	var slot := ModelSlot.new()
	slot.name = "PenguinModelSlot"
	slot.model_id = "penguin_chick_plush"
	slot.target_height = 0.55
	_visual.add_child(slot)


func _build_placeholder() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var body := MeshInstance3D.new()
	body.name = "PenguinBody"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.16
	capsule.height = 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.47, 0.52) # chick grey
	capsule.material = mat
	body.mesh = capsule
	body.position = Vector3(0.0, 0.28, 0.0)
	_visual.add_child(body)

	var belly := MeshInstance3D.new()
	belly.name = "PenguinBelly"
	var belly_mesh := SphereMesh.new()
	belly_mesh.radius = 0.12
	belly_mesh.height = 0.24
	var belly_mat := StandardMaterial3D.new()
	belly_mat.albedo_color = Color(0.96, 0.95, 0.91) # milk-white belly
	belly_mesh.material = belly_mat
	belly.mesh = belly_mesh
	belly.position = Vector3(0.0, 0.24, 0.12)
	_visual.add_child(belly)


func _physics_process(delta: float) -> void:
	_greet_cooldown = maxf(_greet_cooldown - delta, 0.0)

	if _greeting >= 0.0:
		_update_greet(delta)
		return

	var near: PlayerBody = _nearest_player()
	if near != null and _greet_cooldown <= 0.0:
		_greeting = 0.0
		AudioManager.play_sfx("mouse_squeak") # the closest thing the pack has to a cheep
		print("SHORE_FRIEND %s" % JSON.stringify({"kind": "penguin", "event": "greet"}))
		return

	_update_waddle(delta)


func _update_waddle(delta: float) -> void:
	var target: Vector3 = _point_b if _toward_b else _point_a
	var to_target: Vector3 = target - global_position
	if to_target.length() < 0.15:
		_toward_b = not _toward_b
		return
	var step: Vector3 = to_target.normalized() * WADDLE_SPEED * delta
	global_position += step

	_rock_time += delta
	_face_toward(target, delta)
	if _visual != null:
		_visual.rotation.z = deg_to_rad(WADDLE_ROCK_DEG) * sin(_rock_time * TAU * WADDLE_ROCK_HZ * 0.5)
		_update_hop(delta)


func _update_hop(delta: float) -> void:
	if _hop_phase >= 0.0:
		_hop_phase += delta * 3.5
		if _hop_phase >= 1.0:
			_hop_phase = -1.0
			_visual.position.y = 0.0
		else:
			_visual.position.y = HOP_HEIGHT * sin(_hop_phase * PI)
		return
	_hop_timer -= delta
	if _hop_timer <= 0.0:
		_hop_timer = HOP_INTERVAL * randf_range(0.6, 1.4)
		_hop_phase = 0.0


func _update_greet(delta: float) -> void:
	_greeting += delta
	var near: PlayerBody = _nearest_player()
	if near != null:
		_face_toward(near.global_position, delta)
	# Two quick excited bounces over ~1.2 s, then back to the patrol.
	var bounce: float = _greeting * (float(GREET_BOUNCES) / 1.2)
	if _visual != null:
		_visual.position.y = HOP_HEIGHT * 1.3 * absf(sin(bounce * PI))
	if _greeting >= 1.2:
		_greeting = -1.0
		_greet_cooldown = GREET_COOLDOWN
		if _visual != null:
			_visual.position.y = 0.0


func _face_toward(point: Vector3, delta: float) -> void:
	var to_point: Vector3 = point - global_position
	to_point.y = 0.0
	if to_point.length_squared() < 0.001:
		return
	var target_yaw: float = atan2(to_point.x, to_point.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, TURN_SPEED * delta)


func _nearest_player() -> PlayerBody:
	var best: PlayerBody = null
	var best_d: float = GREET_RADIUS
	for node: Node in get_tree().get_nodes_in_group("players"):
		if node is PlayerBody:
			var d: float = (node as PlayerBody).global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = node as PlayerBody
	return best
