class_name CarryToss
extends Node
## CarryToss — Otto's carry/toss verb (D7). Attached as a child of Otto in
## otto.tscn. Owns the one relationship it manages: Otto <-> Pip carry
## state, and every input path that touches it (co-op's own p2 buttons,
## Pip's p1 hop-down, and solo's buddy-mode p1-triggered toss) so no two
## scripts can race on the same button press.
##
## Co-op (input_driven = true, set by seat_manager.gd): Otto's own
## p2_interact near Pip = pick up; p2_interact again or p2_jump = toss.
## Solo (input_driven = false): Pip's own p1_interact near buddy-Otto does
## the whole pick-up-and-toss in one press (there is no second player to
## make the second press). In both modes, Pip's p1_interact while carried
## always means "hop down gently" — that check runs first and consumes the
## press so the two paths can never double-fire in the same frame.

@export var carry_range: float = 1.2
@export var toss_up_velocity: float = 7.5
@export var toss_forward_velocity: float = 3.0
@export var hop_down_lift: float = 0.05

## true in co-op (Otto's own buttons drive pickup/toss); false in solo
## (seat_manager.gd flips this off, buddy_ai.gd never touches CarryToss's
## input path — Pip's own p1_interact still works below either way).
var input_driven: bool = true

var _otto: PlayerBody = null
var _pip: PlayerBody = null
var _carrying: bool = false


func setup(pip: PlayerBody, otto: PlayerBody) -> void:
	_pip = pip
	_otto = otto


func is_carrying() -> bool:
	return _carrying


func _physics_process(_delta: float) -> void:
	if _otto == null or _pip == null:
		return

	if Input.is_action_just_pressed("p1_interact"):
		if _carrying:
			hop_down()
		elif not input_driven:
			_try_solo_toss()
		return # consume this frame's p1_interact either way

	if not input_driven:
		return

	if Input.is_action_just_pressed("p2_interact"):
		if _carrying:
			toss()
		else:
			try_pickup()
	elif _carrying and Input.is_action_just_pressed("p2_jump"):
		toss()


func _try_solo_toss() -> void:
	var dist: float = _otto.global_position.distance_to(_pip.global_position)
	if dist <= carry_range and try_pickup():
		toss()


func try_pickup() -> bool:
	if _carrying or _otto == null or _pip == null:
		return false
	if _pip.state == PlayerBody.State.CARRIED or _pip.state == PlayerBody.State.BUBBLED:
		return false
	var dist: float = _otto.global_position.distance_to(_pip.global_position)
	if dist > carry_range:
		return false

	_carrying = true
	_pip.enter_carried()
	_pip.trigger_squash()
	_otto.trigger_squash()

	var socket: Node3D = _otto.get_node_or_null("CarrySocket") as Node3D
	if socket != null:
		var prev_parent: Node = _pip.get_parent()
		prev_parent.remove_child(_pip)
		socket.add_child(_pip)
		_pip.position = Vector3.ZERO

	print("CARRY {}")
	return true


func toss() -> bool:
	if not _carrying or _otto == null or _pip == null:
		return false
	_carrying = false

	var launch_pos: Vector3 = _release_from_socket()
	_pip.global_position = launch_pos

	var facing: Vector3 = _otto_facing()
	var launch_velocity: Vector3 = facing * toss_forward_velocity + Vector3.UP * toss_up_velocity
	_pip.launch(launch_velocity)

	print("TOSS {}")
	return true


func hop_down() -> void:
	if not _carrying or _otto == null or _pip == null:
		return
	_carrying = false
	var drop_pos: Vector3 = _release_from_socket() + Vector3.UP * hop_down_lift
	_pip.global_position = drop_pos
	_pip.exit_special_state()


## _release_from_socket — reparents Pip from Otto's CarrySocket back to the
## world root (preserving its current global position), returns that
## position. No-op (returns current global_position) if not parented there.
func _release_from_socket() -> Vector3:
	var socket: Node3D = _otto.get_node_or_null("CarrySocket") as Node3D
	var pos: Vector3 = _pip.global_position
	if socket != null and _pip.get_parent() == socket:
		socket.remove_child(_pip)
		var world: Node = _otto.get_tree().current_scene
		world.add_child(_pip)
		_pip.global_position = pos
	return pos


func _otto_facing() -> Vector3:
	var visual: Node3D = _otto.get_node_or_null("Visual") as Node3D
	if visual == null:
		return Vector3.FORWARD
	var yaw: float = visual.rotation.y
	return Vector3(sin(yaw), 0.0, cos(yaw))
