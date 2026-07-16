class_name SoftLanding
extends Node
## SoftLanding — the rescue system (D6, SPEC.md). Tracks a ring buffer of
## each player's last safe (grounded) positions and, when a player falls
## below rescue_floor_y, catches them in a BubbleEffect and floats them
## back to the most recent safe position. Zero fail states; no counter
## shown; never a penalty.
##
## rescue_floor_y is wired by main.gd from the loaded world's
## WorldContract.rescue_floor_y() (fallback -10.0 if no world/contract).
##
## --testfall=true (Harness flag) teleports Pip far below the floor 1s
## after ready(), for the harness/verify RESCUE-receipt property test.
## Left in permanently, gated behind the flag, per the build brief.

const BUBBLE_SCENE: PackedScene = preload("res://core/rescue/bubble_effect.tscn")
const HISTORY_SIZE: int = 24
const SAMPLE_INTERVAL: float = 0.5
const RESCUE_SFX: String = "bubble_catch"
const TEST_FALL_DELAY: float = 1.0
const TEST_FALL_POSITION: Vector3 = Vector3(0.0, -30.0, 0.0)

signal player_rescued(seat: int)

@export var rescue_floor_y: float = -10.0

var _pip: PlayerBody = null
var _otto: PlayerBody = null
var _pip_history: Array[Vector3] = []
var _otto_history: Array[Vector3] = []
var _pip_sample_timer: float = 0.0
var _otto_sample_timer: float = 0.0
var _pip_rescuing: bool = false
var _otto_rescuing: bool = false


func setup(pip: PlayerBody, otto: PlayerBody) -> void:
	_pip = pip
	_otto = otto


func _ready() -> void:
	if Harness.flag("testfall", false):
		var timer: SceneTreeTimer = get_tree().create_timer(TEST_FALL_DELAY)
		timer.timeout.connect(_do_test_fall)
		player_rescued.connect(_on_test_fall_rescued)


## _on_test_fall_rescued — verification-only receipt (--testfall): confirms
## Pip actually landed back above the rescue floor, not just that the
## RESCUE line printed.
func _on_test_fall_rescued(seat: int) -> void:
	if seat != 1 or _pip == null:
		return
	print("TESTFALL_RESULT %s" % JSON.stringify({
		"seat": seat,
		"y": _pip.global_position.y,
		"above_floor": _pip.global_position.y > rescue_floor_y,
	}))


func _do_test_fall() -> void:
	if _pip != null:
		_pip.global_position = TEST_FALL_POSITION


func _physics_process(delta: float) -> void:
	if _pip != null:
		_track_and_check(_pip, delta, true)
	if _otto != null:
		_track_and_check(_otto, delta, false)


func _track_and_check(player: PlayerBody, delta: float, is_pip: bool) -> void:
	var history: Array[Vector3] = _pip_history if is_pip else _otto_history

	if player.is_on_floor() and player.state != PlayerBody.State.BUBBLED:
		var timer: float = _pip_sample_timer if is_pip else _otto_sample_timer
		timer -= delta
		if timer <= 0.0:
			history.append(player.global_position)
			if history.size() > HISTORY_SIZE:
				history.pop_front()
			timer = SAMPLE_INTERVAL
		if is_pip:
			_pip_sample_timer = timer
		else:
			_otto_sample_timer = timer

	var rescuing: bool = _pip_rescuing if is_pip else _otto_rescuing
	if rescuing or player.state == PlayerBody.State.BUBBLED:
		return
	if player.global_position.y < rescue_floor_y:
		_rescue(player, history, is_pip)


func _rescue(player: PlayerBody, history: Array[Vector3], is_pip: bool) -> void:
	if is_pip:
		_pip_rescuing = true
	else:
		_otto_rescuing = true

	print("RESCUE %s" % JSON.stringify({"seat": player.seat}))

	# Not the NEWEST sample: that can be the very lip the player just walked
	# off (grounded on the corner pixel), and setting them back there re-drops
	# them — an instant second rescue. A few samples back is ~1.5-2 s of walk,
	# comfortably inland, and reads as "set down a little way back" anyway.
	var safe_index: int = max(history.size() - 4, 0)
	var safe_pos: Vector3 = history[safe_index] if not history.is_empty() else Vector3.ZERO
	var bubble: BubbleEffect = BUBBLE_SCENE.instantiate()
	get_tree().current_scene.add_child(bubble)
	bubble.finished.connect(_on_rescue_finished.bind(player, is_pip))
	bubble.play(player, safe_pos, RESCUE_SFX)


func _on_rescue_finished(player: PlayerBody, is_pip: bool) -> void:
	if is_pip:
		_pip_rescuing = false
	else:
		_otto_rescuing = false
	player_rescued.emit(player.seat)
