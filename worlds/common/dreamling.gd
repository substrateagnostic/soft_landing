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
var _carrier: Node3D = null
var _orbit_phase: float = randf() * TAU
var _release_elapsed: float = 0.0
var _release_start: Vector3 = Vector3.ZERO
var _release_target: Vector3 = Vector3.ZERO
var _release_then_free: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2 # PlayerBody layer (scenes/players/pip.tscn, otto.tscn)
	body_entered.connect(_on_body_entered)
	_idle_base_local_position = position


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
	position = _idle_base_local_position + Vector3(0.0, sin(_bob_phase) * BOB_AMPLITUDE, 0.0)
	_spin(delta)


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
	monitoring = false
	AudioManager.play_sfx("dreamling_chime")
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
	scale = Vector3.ONE * (1.0 - eased)
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
