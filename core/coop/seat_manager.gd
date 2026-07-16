class_name SeatManager
extends Node
## SeatManager — consumes InputRouter.mode_changed (COOP: both players
## input-active; SOLO: Otto becomes buddy AI, D7) and CameraRig.leash_broken
## (bubble-warps the stray player back beside their anchored partner).
## Shares one bubble vocabulary (core/rescue/bubble_effect.gd) with the
## rescue system — warp_player_to() is also called directly by buddy_ai.gd
## for its own "left too far behind" case, so every gentle-catch in the
## game looks the same.

const BUBBLE_SCENE: PackedScene = preload("res://core/rescue/bubble_effect.tscn")
const WARP_SFX: String = "bubble_catch"
const WARP_SIDE_OFFSET: float = 1.5
const WARP_DURATION: float = 1.5

var _pip: PlayerBody = null
var _otto: PlayerBody = null
var _camera_rig: CameraRig = null
var _buddy_ai: BuddyAI = null
var _carry_toss: CarryToss = null
var _warping: Dictionary = {} # seat:int -> bool


func setup(pip: PlayerBody, otto: PlayerBody, camera_rig: CameraRig, buddy_ai: BuddyAI, carry_toss: CarryToss) -> void:
	_pip = pip
	_otto = otto
	_camera_rig = camera_rig
	_buddy_ai = buddy_ai
	_carry_toss = carry_toss

	InputRouter.mode_changed.connect(_on_mode_changed)
	if _camera_rig != null:
		_camera_rig.leash_broken.connect(_on_leash_broken)

	_apply_mode(InputRouter.is_coop())


func _on_mode_changed(_mode: int) -> void:
	_apply_mode(InputRouter.is_coop())


func _apply_mode(coop: bool) -> void:
	if _carry_toss != null:
		_carry_toss.input_driven = coop
	if _buddy_ai != null:
		_buddy_ai.active = not coop
	if coop and _otto != null:
		_otto.clear_virtual_input()
	if _camera_rig != null:
		_camera_rig.set_solo(not coop)


func _on_leash_broken(player: PlayerBody) -> void:
	var partner: PlayerBody = _otto if player == _pip else _pip
	if partner == null:
		return
	warp_player_to(player, partner.global_position + _side_offset(partner))


## warp_player_to — same bubble visual as the rescue system, shorter float.
## No-op if `player` is already mid-warp (or mid-rescue, since BubbleEffect
## puts them in BUBBLED either way).
func warp_player_to(player: PlayerBody, target_position: Vector3) -> void:
	if player == null:
		return
	var seat: int = player.seat
	if _warping.get(seat, false) or player.state == PlayerBody.State.BUBBLED:
		return
	_warping[seat] = true
	print("WARP %s" % JSON.stringify({"seat": seat}))

	var bubble: BubbleEffect = BUBBLE_SCENE.instantiate()
	get_tree().current_scene.add_child(bubble)
	bubble.finished.connect(_on_warp_finished.bind(seat))
	bubble.play(player, target_position, WARP_SFX, WARP_DURATION)


func _on_warp_finished(seat: int) -> void:
	_warping[seat] = false


func _side_offset(partner: PlayerBody) -> Vector3:
	var visual: Node3D = partner.get_node_or_null("Visual") as Node3D
	var yaw: float = visual.rotation.y if visual != null else 0.0
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	return right * WARP_SIDE_OFFSET
