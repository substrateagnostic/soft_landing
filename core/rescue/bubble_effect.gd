class_name BubbleEffect
extends Node3D
## BubbleEffect — the Soft Landing / Warp bubble, one shared visual
## vocabulary (D6/D9/D5) used by both soft_landing.gd (rescue) and
## seat_manager.gd (frustum-leash / buddy-lag warp): wraps a player in a
## translucent blush sphere, tweens them to a target position, pops, and
## frees itself. Instantiate fresh per use (see either caller).

signal finished

@export var float_duration: float = 2.5
@export var lift_height: float = 1.0
@export var pop_scale_time: float = 0.25

@onready var _mesh: MeshInstance3D = $MeshInstance3D

var _player: PlayerBody = null
var _start_pos: Vector3 = Vector3.ZERO
var _end_pos: Vector3 = Vector3.ZERO


## play — puts `player` into the BUBBLED state, floats them to
## `target_position` (+ lift_height) over `duration_override` seconds (or
## float_duration if <= 0), plays `sfx_name`, pops, restores control, and
## frees this node. Emits `finished` when the whole sequence completes.
func play(player: PlayerBody, target_position: Vector3, sfx_name: String, duration_override: float = -1.0) -> void:
	_player = player
	var duration: float = duration_override if duration_override > 0.0 else float_duration

	player.enter_bubbled()
	global_position = player.global_position
	AudioManager.play_sfx(sfx_name)

	_start_pos = global_position
	_end_pos = target_position + Vector3.UP * lift_height

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_on_float_step, 0.0, 1.0, duration)
	await tween.finished

	var pop_tween: Tween = create_tween()
	pop_tween.tween_property(_mesh, "scale", Vector3.ONE * 1.4, pop_scale_time)
	await pop_tween.finished

	player.exit_special_state()
	finished.emit()
	queue_free()


func _on_float_step(t: float) -> void:
	var pos: Vector3 = _start_pos.lerp(_end_pos, t)
	global_position = pos
	if _player != null:
		_player.global_position = pos
