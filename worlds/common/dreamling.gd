class_name Dreamling
extends Area3D
## Dreamling — the collectible (PITCH.md, D12). Idle: bobs + spins in place,
## waiting to be touched. Touched by a PlayerBody: chimes, tells the world it
## was collected, and enters FOLLOW mode — orbiting its carrier, spacing
## itself by angle among any siblings that carrier already has (a shared
## per-carrier registry, so a duck carrying three dreamlings sees a neat
## little ring, not a pile). release_to() is called by DreamDoor on return:
## flies to the door, shrinks, frees itself.

signal collected(id: String)

const BOB_AMPLITUDE: float = 0.15
const BOB_HZ: float = 0.5
const SPIN_SPEED: float = 1.5 # rad/s, idle visual spin
# Generosity (D12 + the Kirby "fuzzy" lesson): dreams WANT to be found.
# Within ATTRACT_RADIUS a dreamling drifts toward the nearest player, so a
# near-miss becomes a catch; with nobody near it drifts home to its perch.
const ATTRACT_RADIUS: float = 2.2
const ATTRACT_SPEED: float = 3.5 # m/s, at closest; eases in from the rim
const HOME_SPEED: float = 1.0
const PLAYERS_GROUP: String = "players"
const ORBIT_RADIUS: float = 0.7
const ORBIT_HEIGHT: float = 1.6
const ORBIT_ANGULAR_SPEED: float = 1.2 # rad/s, slow shared drift so the ring reads as alive, not static
const FOLLOW_LAG_K: float = 3.0 # exp-decay follow lag, "trail dreamily"
const RELEASE_DURATION: float = 0.5

enum State { IDLE, FOLLOWING, RELEASING }

## carrier instance id -> Array[Dreamling] currently orbiting it, so siblings
## space themselves by angle without any of them needing a central manager.
static var _orbit_groups: Dictionary = {}

@export var id: String = ""

@onready var _visual: Node3D = get_node_or_null("Visual") as Node3D

var _state: State = State.IDLE
var _bob_phase: float = randf() * TAU
var _idle_base_local_position: Vector3 = Vector3.ZERO
var _home_local_position: Vector3 = Vector3.ZERO
var _carrier: Node3D = null
var _orbit_phase: float = randf() * TAU
var _release_elapsed: float = 0.0
var _release_start: Vector3 = Vector3.ZERO
var _release_target: Vector3 = Vector3.ZERO
var _release_then_free: bool = false

## D21 micro-mission hook (worlds/common/mission_driver.gd). ADDITIVE on top
## of the idle bob/magnetism anchor, never a replacement for it -- a
## dreamling with no attached MissionDriver never has this set away from
## ZERO, so "open" archetype / no-mission-data worlds are byte-for-byte
## unchanged (D21: "zero behavior change"). Public so a MissionDriver
## (a plain sibling component, not a subclass) can drive it without this
## script needing to know any archetype exists.
var mission_suppress_magnetism: bool = false
var _mission_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2 # PlayerBody layer (scenes/players/pip.tscn, otto.tscn)
	body_entered.connect(_on_body_entered)
	_idle_base_local_position = position
	_home_local_position = position


## Carriers (the players) outlive worlds. Without this, every world switch
## leaves freed dreamlings in the static registry under the surviving
## carrier's id — corrupting orbit spacing and handing freed instances to
## the DreamDoor. (Opus review 2026-07-16, finding #3.)
func _exit_tree() -> void:
	_leave_orbit_group()


func _physics_process(delta: float) -> void:
	match _state:
		State.IDLE:
			_process_idle(delta)
		State.FOLLOWING:
			_process_following(delta)
		State.RELEASING:
			_process_releasing(delta)


## Bobs in the PARENT's local space, not world space — so a dreamling
## parented to a moving platform (d06 rides Bramble's breathing chest) bobs
## relative to that platform instead of fighting its motion every frame.
func _process_idle(delta: float) -> void:
	_bob_phase = fmod(_bob_phase + delta * BOB_HZ * TAU, TAU)
	if not mission_suppress_magnetism:
		_apply_magnetism(delta)
	position = _idle_base_local_position + _mission_offset + Vector3(0.0, sin(_bob_phase) * BOB_AMPLITUDE, 0.0)
	_spin(delta)


## Nudges the dreamling away from its idle anchor without touching the
## anchor itself (_idle_base_local_position keeps homing toward
## _home_local_position exactly as before) -- so a mission driver can be
## deleted or bugged out entirely and the dreamling still settles back to
## its exact placement, never a drifted one. Called every physics frame by
## an attached MissionDriver for the `race`/`ride` archetypes only.
func mission_set_local_offset(offset: Vector3) -> void:
	_mission_offset = offset


func mission_current_offset() -> Vector3:
	return _mission_offset


func _apply_magnetism(delta: float) -> void:
	var parent: Node3D = get_parent() as Node3D
	if parent == null:
		return
	var nearest: Node3D = _nearest_player()
	var drift_global: Vector3
	if nearest != null:
		var to_player: Vector3 = (nearest.global_position + Vector3(0.0, 0.9, 0.0)) - global_position
		var dist: float = to_player.length()
		if dist < 0.05:
			return
		# Eases in from the rim: barely a lean at the edge, an eager little
		# rush right next to you.
		var pull: float = clamp(1.0 - dist / ATTRACT_RADIUS, 0.0, 1.0)
		drift_global = to_player.normalized() * ATTRACT_SPEED * pull * delta
	else:
		var home_global: Vector3 = parent.to_global(_home_local_position)
		var to_home: Vector3 = home_global - parent.to_global(_idle_base_local_position)
		if to_home.length() < 0.05:
			return
		drift_global = to_home.limit_length(HOME_SPEED * delta)
	_idle_base_local_position += parent.global_transform.basis.inverse() * drift_global


func _nearest_player() -> Node3D:
	var best: Node3D = null
	var best_dist: float = ATTRACT_RADIUS
	for node: Node in get_tree().get_nodes_in_group(PLAYERS_GROUP):
		var player: Node3D = node as Node3D
		if player == null:
			continue
		var dist: float = player.global_position.distance_to(global_position)
		if dist < best_dist:
			best_dist = dist
			best = player
	return best


func _spin(delta: float) -> void:
	if _visual != null:
		_visual.rotate_y(SPIN_SPEED * delta)


func _on_body_entered(body: Node3D) -> void:
	if _state != State.IDLE:
		return
	if not (body is PlayerBody):
		return
	_start_following(body)


func _start_following(carrier: Node3D) -> void:
	_state = State.FOLLOWING
	_carrier = carrier
	set_deferred("monitoring", false) # direct set is blocked inside body_entered
	# The ladder climbs with each dream you're carrying (counting IS the joy,
	# D12): first catch low, each next one a step higher, resetting when you
	# bring them home and the orbit empties.
	AudioManager.play_chime(Dreamling.carried_by(carrier).size() + 1)
	collected.emit(id)
	_join_orbit_group(carrier)


func _join_orbit_group(carrier: Node3D) -> void:
	var key: int = carrier.get_instance_id()
	if not _orbit_groups.has(key):
		_orbit_groups[key] = []
	(_orbit_groups[key] as Array).append(self)


func _leave_orbit_group() -> void:
	if _carrier == null:
		return
	var key: int = _carrier.get_instance_id()
	if _orbit_groups.has(key):
		(_orbit_groups[key] as Array).erase(self)
		if (_orbit_groups[key] as Array).is_empty():
			_orbit_groups.erase(key)


func _process_following(delta: float) -> void:
	if _carrier == null or not is_instance_valid(_carrier):
		return
	var group: Array = _orbit_groups.get(_carrier.get_instance_id(), [self])
	var index: int = group.find(self)
	var count: int = max(group.size(), 1)
	var angle_step: float = TAU / count
	_orbit_phase += ORBIT_ANGULAR_SPEED * delta
	var angle: float = _orbit_phase + index * angle_step
	var orbit_center: Vector3 = (_carrier as Node3D).global_position + Vector3(0.0, ORBIT_HEIGHT, 0.0)
	var target: Vector3 = orbit_center + Vector3(cos(angle), 0.0, sin(angle)) * ORBIT_RADIUS
	var weight: float = 1.0 - exp(-FOLLOW_LAG_K * delta)
	global_position = global_position.lerp(target, weight)
	_spin(delta)


## Called by DreamDoor the moment a return is SCHEDULED, so the staggered
## release window can't double-schedule (the door polls the orbit registry
## every frame).
func leave_orbit_early() -> void:
	_leave_orbit_group()


## Called by DreamDoor on return. Flies to `point`, shrinks to nothing, then
## frees itself (or just hides, if `then_free` is false — kept general per
## the contract signature even though the only current caller always frees).
func release_to(point: Vector3, then_free: bool) -> void:
	if _state == State.RELEASING:
		return
	_leave_orbit_group()
	_state = State.RELEASING
	_release_start = global_position
	_release_target = point
	_release_elapsed = 0.0
	_release_then_free = then_free


func _process_releasing(delta: float) -> void:
	_release_elapsed += delta
	var t: float = clamp(_release_elapsed / RELEASE_DURATION, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0) # ease-out, a gentle arrival not a snap
	global_position = _release_start.lerp(_release_target, eased)
	# Never exactly zero: a zero-scale basis is non-invertible and the
	# engine logs det==0 errors on the frame before queue_free lands.
	scale = Vector3.ONE * max(1.0 - eased, 0.01)
	if t >= 1.0:
		if _release_then_free:
			queue_free()
		else:
			visible = false
			set_physics_process(false)


## The dreamlings currently orbiting `carrier` (a duplicate array — safe for
## callers to iterate while dreamlings release themselves from the group).
static func carried_by(carrier: Node3D) -> Array:
	return (_orbit_groups.get(carrier.get_instance_id(), []) as Array).duplicate()
