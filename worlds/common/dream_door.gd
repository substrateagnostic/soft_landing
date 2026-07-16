class_name DreamDoor
extends Area3D
## DreamDoor — the "ear": the return point for carried dreamlings
## (PITCH.md, SPEC.md). A PlayerBody carrying orbiting dreamlings that
## overlaps this area releases each one home, staggered so they land as a
## soft chime ladder rather than all at once.

signal returned(id: String)

const RELEASE_STAGGER: float = 0.3
const RELEASE_THEN_FREE: bool = true
## The door's disk is exactly the kind of prop kids already stand on for a
## reason (delivering a dream) — a natural, in-territory "poke" opt-in for
## worlds/common/world_base.gd's auto-attach pass (Top 12 #6), reused for
## free across every world that instantiates dream_door.tscn (bramble,
## wisp, marmalade) with zero edits to any of their own scripts. Radius
## matches the door's CylinderMesh top_radius (0.9 m) from dream_door.tscn.
const _VISUAL_POKE_RADIUS: float = 0.9


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2 # PlayerBody layer
	_opt_visual_into_poke()


func _opt_visual_into_poke() -> void:
	var visual: Node = get_node_or_null("Visual")
	if visual == null:
		return
	visual.add_to_group("poke")
	visual.set_meta("touch_react_radius", _VISUAL_POKE_RADIUS)
	# Deliberately NOT "dream_home" (assets/audio/sfx/dream_home.ogg, played
	# by _on_release_timer on a REAL return) — reusing it here would make a
	# player think a dream just came home every time they merely stood on
	# the disk. TouchReact's default "poke_boop" has no asset yet and fails
	# soft (AudioManager's documented convention): the wobble still plays,
	# audio arrives with a later asset pass, no false-positive meaning
	# borrowed from a different receipt in the meantime.


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
