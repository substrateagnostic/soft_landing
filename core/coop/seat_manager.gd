class_name SeatManager
extends Node
## SeatManager — consumes InputRouter.mode_changed (COOP: both players
## input-active; SOLO: Otto becomes buddy AI, D7). Shares one bubble
## vocabulary (core/rescue/bubble_effect.gd) with the rescue system —
## warp_player_to() is called by buddy_ai.gd for its "left too far behind"
## case, so every gentle-catch in the game looks the same.
##
## D27: the CameraRig frustum-leash consumption is GONE — in split-screen
## (CameraDirector) every player is always framed by their own camera, so
## there is no "outside the frame" state to warp anyone out of. Its warp
## was also the producer-reported "teleport kept dropping me off the map"
## bug: the target was partner + 1.5m sideways with NO ground check, so a
## partner near an edge fed the warped player straight into the void, the
## rescue floated them back, and the loop repeated. Every warp target now
## ground-validates first (raycast down), falling back to the exact
## partner/leader position — which is proven standable — or, failing even
## that, skipping the warp entirely (the rescue system remains the net).

const BUBBLE_SCENE: PackedScene = preload("res://core/rescue/bubble_effect.tscn")
const WARP_SFX: String = "bubble_catch"
const WARP_DURATION: float = 1.5
const WORLD_GEOMETRY_MASK: int = 1
const GROUND_PROBE_UP: float = 2.0 # probe starts this far above the target...
const GROUND_PROBE_DOWN: float = 6.0 # ...and looks this far below it

var _pip: PlayerBody = null
var _otto: PlayerBody = null
var _buddy_ai: BuddyAI = null
var _carry_toss: CarryToss = null
var _warping: Dictionary = {} # seat:int -> bool
var _skip_until_ms: Dictionary = {} # seat:int -> ticks_msec; rate-limits no-ground retries

const SKIP_RETRY_MS: int = 1500


func setup(pip: PlayerBody, otto: PlayerBody, buddy_ai: BuddyAI, carry_toss: CarryToss) -> void:
	_pip = pip
	_otto = otto
	_buddy_ai = buddy_ai
	_carry_toss = carry_toss

	InputRouter.mode_changed.connect(_on_mode_changed)
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


## warp_player_to — same bubble visual as the rescue system, shorter float.
## No-op if `player` is already mid-warp (or mid-rescue, since BubbleEffect
## puts them in BUBBLED either way). The target is ground-validated (D27);
## when it hangs over nothing, the warp lands on the partner's own proven
## footing instead, and if even that fails the warp is skipped.
func warp_player_to(player: PlayerBody, target_position: Vector3) -> void:
	if player == null:
		return
	var seat: int = player.seat
	if _warping.get(seat, false) or player.state == PlayerBody.State.BUBBLED:
		return

	if Time.get_ticks_msec() < int(_skip_until_ms.get(seat, 0)):
		return # a recent no-ground skip; don't re-probe every frame (buddy AI retries continuously)

	var partner: PlayerBody = _otto if player == _pip else _pip
	var validated: Vector3 = target_position
	if not _has_ground_under(player, target_position):
		if partner != null and _has_ground_under(player, partner.global_position):
			validated = partner.global_position
		else:
			_skip_until_ms[seat] = Time.get_ticks_msec() + SKIP_RETRY_MS
			print("WARP_SKIPPED %s" % JSON.stringify({"seat": seat, "reason": "no_ground"}))
			return

	_warping[seat] = true
	print("WARP %s" % JSON.stringify({"seat": seat}))

	var bubble: BubbleEffect = BUBBLE_SCENE.instantiate()
	get_tree().current_scene.add_child(bubble)
	bubble.finished.connect(_on_warp_finished.bind(seat))
	bubble.play(player, validated, WARP_SFX, WARP_DURATION)


func _on_warp_finished(seat: int) -> void:
	_warping[seat] = false


func _has_ground_under(player: PlayerBody, point: Vector3) -> bool:
	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * GROUND_PROBE_UP,
		point + Vector3.DOWN * GROUND_PROBE_DOWN
	)
	query.collision_mask = WORLD_GEOMETRY_MASK
	return not space_state.intersect_ray(query).is_empty()
