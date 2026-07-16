class_name BuddyAI
extends Node
## BuddyAI — Otto follow-AI for solo mode (D7). Reliability over smarts:
## straight-line steering via PlayerBody.set_virtual_input()/request_jump()
## (never touches Input directly — Otto's real p2 bindings stay untouched
## for hot-swap back to co-op), mirrors Pip's jump near gaps, and
## lag-warps through SeatManager's shared bubble vocabulary when left too
## far behind. carry_toss.gd owns the "walk up + p1_interact = toss" input
## path itself, so buddy_ai never touches carry/toss input.

@export var follow_distance: float = 2.5
@export var jump_mirror_distance: float = 4.0
@export var lag_warp_distance: float = 12.0
@export var stop_threshold: float = 0.3

## true only in solo mode (seat_manager.gd flips this).
var active: bool = false

var _pip: PlayerBody = null
var _otto: PlayerBody = null
var _seat_manager: SeatManager = null


func setup(pip: PlayerBody, otto: PlayerBody, seat_manager: SeatManager) -> void:
	_pip = pip
	_otto = otto
	_seat_manager = seat_manager
	_pip.jumped.connect(_on_pip_jumped)


func _physics_process(_delta: float) -> void:
	if not active or _pip == null or _otto == null:
		return
	if _otto.state == PlayerBody.State.CARRIED or _otto.state == PlayerBody.State.BUBBLED:
		return # mid rescue/warp/carry — don't fight the system driving it

	var to_pip: Vector3 = _pip.global_position - _otto.global_position
	to_pip.y = 0.0
	var distance: float = to_pip.length()

	if distance > lag_warp_distance:
		_lag_warp()
		return

	var move_vec: Vector2 = Vector2.ZERO
	if distance > follow_distance:
		var dir: Vector3 = to_pip.normalized()
		var eased: float = clampf((distance - follow_distance) / stop_threshold, 0.0, 1.0)
		move_vec = Vector2(dir.x, dir.z) * eased
	_otto.set_virtual_input(move_vec)


func _on_pip_jumped() -> void:
	if not active or _pip == null or _otto == null:
		return
	var horizontal_dist: float = Vector2(
		_pip.global_position.x - _otto.global_position.x,
		_pip.global_position.z - _otto.global_position.z
	).length()
	if horizontal_dist < jump_mirror_distance and _otto.is_on_floor():
		_otto.request_jump()


func _lag_warp() -> void:
	if _seat_manager == null:
		return
	var behind: Vector3 = -_pip.velocity
	behind.y = 0.0
	if behind.length() < 0.01:
		behind = Vector3.FORWARD
	var target: Vector3 = _pip.global_position + behind.normalized() * follow_distance
	_seat_manager.warp_player_to(_otto, target)
