class_name DreamDoor
extends Area3D
## DreamDoor — the "ear": the return point for carried dreamlings
## (PITCH.md, SPEC.md). A PlayerBody carrying orbiting dreamlings that
## overlaps this area releases each one home, staggered so they land as a
## soft chime ladder rather than all at once.

signal returned(id: String)

const RELEASE_STAGGER: float = 0.3
const RELEASE_THEN_FREE: bool = true


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2 # PlayerBody layer


## Polled, not edge-triggered: a player who collects a dreamling while
## ALREADY standing in the door (d10 lives right beside it) never re-fires
## body_entered — the overlap check catches that case every frame. Cheap:
## one door per world, two possible bodies.
func _physics_process(_delta: float) -> void:
	for body: Node3D in get_overlapping_bodies():
		if not (body is PlayerBody):
			continue
		var carried: Array = Dreamling.carried_by(body)
		if not carried.is_empty():
			_release_all(carried)


func _release_all(carried: Array) -> void:
	var delay: float = 0.0
	for dreamling: Dreamling in carried:
		_schedule_release(dreamling, delay)
		delay += RELEASE_STAGGER


func _schedule_release(dreamling: Dreamling, delay: float) -> void:
	# Out of the orbit registry immediately, or next frame's poll would
	# schedule (and count) the same dreamling again during the stagger.
	dreamling.leave_orbit_early()
	var timer: SceneTreeTimer = get_tree().create_timer(delay)
	timer.timeout.connect(_on_release_timer.bind(dreamling))


func _on_release_timer(dreamling: Dreamling) -> void:
	if not is_instance_valid(dreamling):
		return
	var released_id: String = dreamling.id
	dreamling.release_to(global_position, RELEASE_THEN_FREE)
	AudioManager.play_sfx("dream_home")
	returned.emit(released_id)
