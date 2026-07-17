class_name RiseSequence
extends Node3D
## RiseSequence — Tortoise's one-time transformative body-function: THE SLOW
## RISE (M4 keystone, docs/design/world-cards/tortoise.md). At 10/10 dreams,
## Aunt Tortoise — slower than anything in the game — stands, and the whole
## terraced garden built on her shell lifts skyward together over ~12s: a
## hanging-terrace vista, petals drift, nothing falls hard (the world's
## gentlest earthquake). A long hold under the moon, then she settles back
## down with a sigh. Mirrors worlds/wisp/dive_sequence.gd and worlds/
## marmalade/stretch_sequence.gd's proven architecture (world_completed
## trigger + force flag, letterboxed cine camera, bubble-lift safety,
## persistence) — built directly on core/cinematic/cine_sequence.gd (the
## generalized machinery those two files' own headers point at as "an M4
## card, not tonight's" — it is tonight's, here) rather than duplicating
## letterbox code.
##
## Trigger: GameState.world_completed("tortoise") — WorldBase already fires
## this the moment all 10 dreamlings return (worlds/common/world_base.gd
## _check_completion), so "once per save" falls straight out of that existing
## signal, same as every other world's keystone. --rise (Harness.flags)
## force-arms the sequence ~3s after load regardless of dream count, dev/
## capture only (RISE {"phase":...,"forced":true}).
##
## "Whole garden lifts together": rather than reparenting the world's flat,
## check_placements.gd-friendly node layout (every dreamling a direct child
## of the world root, exactly like every other world — see tortoise.gd's own
## header) into a shared moving group at boot, this sequence takes a flat
## ARRAY of the top-level garden nodes (tortoise.gd's own garden_nodes(),
## populated as each piece is built) and tweens `position:y` on every one of
## them by the same delta, in parallel — visually identical to a single
## shared parent, with zero risk of accidentally exempting every dreamling
## from check_placements.gd's ground-gap check the way nesting them all under
## one parent would (see that tool's own `moving_platform` contract).
##
## Safety: EVERY connected player is bubble-lifted (core/rescue/
## bubble_effect.gd, the shared rescue/warp visual vocabulary every keystone
## reuses) to a safe, already-solid meadow point BEFORE anything moves —
## floor law, per the task brief. Ground for the crown reward goes solid
## FIRST, before any camera/tween work — the same "never gate new ground
## behind the full animation length" lesson wisp/marmalade's own files
## already learned live.

signal rise_started
signal rise_finished

## Public (mirrors StretchSequence.playing's own convention): tortoise.gd's
## own ambient shell-breathing _process() checks this so the two animations
## never fight over the same anchor.
var playing: bool = false

const BUBBLE_SCENE: PackedScene = preload("res://core/rescue/bubble_effect.tscn")

# --- Cinematic camera --------------------------------------------------------
const CINE_WIDE_POS: Vector3 = Vector3(-10.0, 24.0, 60.0)
const CINE_WIDE_LOOK: Vector3 = Vector3(30.0, 6.0, 0.0)
const CINE_RISE_POS: Vector3 = Vector3(10.0, 34.0, 56.0)
const CINE_RISE_LOOK: Vector3 = Vector3(32.0, 16.0, 0.0)
const CINE_HOLD_POS: Vector3 = Vector3(18.0, 40.0, 50.0)
const CINE_HOLD_LOOK: Vector3 = Vector3(33.0, 18.0, -3.0)
const CINE_CROWN_POS: Vector3 = Vector3(30.0, 22.0, 14.0)
const CINE_CROWN_LOOK: Vector3 = Vector3(31.0, 12.0, -2.0)
const CINE_TAIL: float = 3.0

# --- The rise choreography ("stands up... over ~12s", per the brief) --------
const RISE_TIME: float = 12.0
const RISE_LIFT: float = 4.0 # meters -- "the world's gentlest earthquake," modest on purpose
const HOLD_TIME: float = 3.0 # "a long beat under the moon"
const SETTLE_TIME: float = 8.0 # slower than every other keystone's own settle -- "slower than anything in the game"

const FORCED_DELAY: float = 3.0
const BUBBLE_DURATION: float = 4.0 # "gently, hugely" -- matches dive_sequence.gd's own majestic-lift phrase
const BUBBLE_LANDING_SPACING: float = 1.4
# Open meadow, clear of every dreamling/dressing/ledge/ramp placement in
# tortoise.gd (checked by hand: nearest is MEADOW_STONE_SOFT_POS at (-9,-1),
# >9m away).
const BUBBLE_LANDING: Vector3 = Vector3(-18.0, 0.5, -12.0)

# --- Petals ("petals drift, nothing falls hard") -----------------------------
const PETAL_EMIT_POS: Vector3 = Vector3(32.0, 18.0, 0.0)
const PETAL_COLOR: Color = Color("E8B4C8")

# --- The crown reward: a small "highest bloom" nook, built hidden at boot,
# revealed during the rise, permanently reachable afterward (Wisp flood-route
# / Marmalade attic-nook "build once, reveal by flip" convention). Its XZ/
# top-Y come from tortoise.gd's own reward_top_point() (computed against the
# shell sphere there); this file only owns the nook's own footprint/props.
const REWARD_SIZE: Vector2 = Vector2(4.5, 4.5)
const REWARD_THICKNESS: float = 0.6
const COLOR_REWARD: Color = Color("E8B4C8") # blush -- reads warmer than the moss terraces
const REWARD_SUBMERGE_OFFSET: float = -2.0
const REWARD_RISE_DURATION: float = 8.0 # the reward's own visual arrival tween, roughly the settle's own pace

var _world: Node3D = null
var _garden_nodes: Array[Node3D] = []
var _garden_rest_y: Array[float] = []
var _reward_top_point: Vector3 = Vector3.ZERO

var _reward_root: Node3D = null
var _reward_shape: CollisionShape3D = null
var _reward_hint_shape: CollisionShape3D = null
var _played: bool = false

var _cine: CineSequence = null
var _petals: GPUParticles3D = null


## setup — called by tortoise.gd BEFORE add_child (established codebase
## ordering: entering the tree fires _ready() synchronously, so a reversed
## order would run _ready() with these still unset).
func setup(world: Node3D, garden_nodes: Array[Node3D], reward_top_point: Vector3) -> void:
	_world = world
	_garden_nodes = garden_nodes
	_reward_top_point = reward_top_point


func _ready() -> void:
	for node: Node3D in _garden_nodes:
		_garden_rest_y.append(node.position.y)

	_cine = CineSequence.new()
	_cine.name = "RiseCine"
	add_child(_cine)
	_cine.setup(_world, "RiseCineCamera", "RiseLetterbox")

	_build_petals()
	_build_reward_geometry()

	if GameState.is_world_completed("tortoise"):
		_apply_already_risen_state()
		return

	GameState.world_completed.connect(_on_world_completed)
	if Harness.flag("rise", false):
		var timer: SceneTreeTimer = get_tree().create_timer(FORCED_DELAY)
		timer.timeout.connect(_on_forced_trigger)


func _on_world_completed(world_id: String) -> void:
	if world_id != "tortoise" or _played:
		return
	_play_sequence(false)


func _on_forced_trigger() -> void:
	if _played:
		return
	_play_sequence(true)


func _play_sequence(forced: bool) -> void:
	_played = true
	playing = true
	print("RISE %s" % JSON.stringify({"phase": "start", "forced": forced}))
	rise_started.emit()
	AudioManager.play_sfx_overlay("giant_rumble") # audio pass note: no dedicated tortoise stems yet -- reused, fails soft (see VERIFY doc)
	TheMoon.say("world_complete") # same generic set-piece key every other keystone reuses

	_reveal_reward_ground() # ground solid FIRST, before any camera/tween work -- the established lesson
	_cine.begin(CINE_WIDE_POS, CINE_WIDE_LOOK)
	_bubble_all_players() # every seat off the terraces and safe BEFORE anything moves
	_cine.dolly_to(CINE_RISE_POS, CINE_RISE_LOOK, RISE_TIME)

	_start_petals()
	await _tween_rise()
	print("RISE %s" % JSON.stringify({"phase": "risen"}))
	AudioManager.play_sfx("giant_yawn_sigh")

	_cine.push_to(CINE_HOLD_POS, CINE_HOLD_LOOK, HOLD_TIME * 0.6)
	var hold_timer: SceneTreeTimer = get_tree().create_timer(HOLD_TIME)
	await hold_timer.timeout
	_stop_petals()

	print("RISE %s" % JSON.stringify({"phase": "settling"}))
	_cine.push_to(CINE_CROWN_POS, CINE_CROWN_LOOK, SETTLE_TIME * 0.8)
	await _tween_settle()
	print("RISE %s" % JSON.stringify({"phase": "settled"}))

	var tail_timer: SceneTreeTimer = get_tree().create_timer(CINE_TAIL)
	await tail_timer.timeout
	_cine.end()

	playing = false
	print("RISE %s" % JSON.stringify({"phase": "end", "forced": forced}))
	rise_finished.emit()


## Reuses the exact rescue/warp visual vocabulary (core/rescue/
## bubble_effect.gd) rather than any bespoke lift. Unconditional (every
## connected player, wherever they stand on the garden) — nothing can ever be
## disturbed out from under someone if no one is ever left on the terraces
## in the first place.
func _bubble_all_players() -> void:
	var offset: float = 0.0
	for player: Node in get_tree().get_nodes_in_group("players"):
		if not (player is PlayerBody):
			continue
		var bubble: BubbleEffect = BUBBLE_SCENE.instantiate()
		get_tree().current_scene.add_child(bubble)
		var landing: Vector3 = BUBBLE_LANDING + Vector3(offset, 0.0, 0.0)
		offset += BUBBLE_LANDING_SPACING
		bubble.play(player as PlayerBody, landing, "bubble_catch", BUBBLE_DURATION)


func _tween_rise() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	for i: int in range(_garden_nodes.size()):
		var node: Node3D = _garden_nodes[i]
		if node == null or not is_instance_valid(node):
			continue
		tween.tween_property(node, "position:y", _garden_rest_y[i] + RISE_LIFT, RISE_TIME)
	await tween.finished


func _tween_settle() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	for i: int in range(_garden_nodes.size()):
		var node: Node3D = _garden_nodes[i]
		if node == null or not is_instance_valid(node):
			continue
		tween.tween_property(node, "position:y", _garden_rest_y[i], SETTLE_TIME)
	await tween.finished


func _apply_already_risen_state() -> void:
	_reveal_reward_ground_immediate()
	for i: int in range(_garden_nodes.size()):
		if _garden_nodes[i] != null and is_instance_valid(_garden_nodes[i]):
			# She's asleep again -- only the reward geometry persists (same
			# "the world remembers the transformation, not the animation"
			# pattern as Wisp's dive / Marmalade's stretch).
			_garden_nodes[i].position.y = _garden_rest_y[i]


func _reveal_reward_ground_immediate() -> void:
	_reward_root.visible = true
	_reward_root.position.y = 0.0
	if _reward_shape != null:
		_reward_shape.disabled = false
	if _reward_hint_shape != null:
		_reward_hint_shape.disabled = false


# --- Crown reward geometry ("a permanently raised step... left behind") -----

func _build_reward_geometry() -> void:
	_reward_root = Node3D.new()
	_reward_root.name = "HighestBloomNook"
	_reward_root.visible = false
	_reward_root.position.y = REWARD_SUBMERGE_OFFSET
	_world.add_child(_reward_root)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(REWARD_SIZE.x, REWARD_THICKNESS, REWARD_SIZE.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_REWARD
	mesh.material = mat
	var center: Vector3 = Vector3(_reward_top_point.x, _reward_top_point.y - REWARD_THICKNESS * 0.5, _reward_top_point.z)

	var visual := MeshInstance3D.new()
	visual.name = "HighestBloomPlatform"
	visual.mesh = mesh
	visual.position = center
	_reward_root.add_child(visual)

	var body := StaticBody3D.new()
	body.name = "HighestBloomPlatformBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = mesh.size
	shape.shape = box_shape
	shape.position = center
	shape.disabled = true # flipped by _reveal_reward_ground()
	body.add_child(shape)
	_reward_root.add_child(body)
	_reward_shape = shape

	_add_reward_props(center)
	_add_reward_hint(center)


## "1-2 props from the existing Meshy set" -- all three already exist on disk
## (tools/meshy/manifest.json target_height_hint: birdhouse_lantern 0.6,
## moon_daisy 0.4, moth_small 0.25), matching Marmalade's own attic-nook
## dressing convention (lantern + a small flower + a moth).
func _add_reward_props(top_center: Vector3) -> void:
	_add_meshy_prop("RewardLantern", "birdhouse_lantern", 0.6, top_center + Vector3(-1.2, REWARD_THICKNESS * 0.5, -0.9))
	_add_meshy_prop("RewardDaisy", "moon_daisy", 0.4, top_center + Vector3(1.1, REWARD_THICKNESS * 0.5, 0.8))
	_add_meshy_prop("RewardMoth", "moth_small", 0.25, top_center + Vector3(0.2, REWARD_THICKNESS * 0.5, -1.3))


func _add_meshy_prop(prop_name: String, model_id: String, height: float, prop_position: Vector3) -> void:
	var anchor := Node3D.new()
	anchor.name = prop_name
	anchor.position = prop_position
	_reward_root.add_child(anchor)
	var slot := ModelSlot.new()
	slot.name = "ModelSlot"
	slot.model_id = model_id
	slot.target_height = height
	anchor.add_child(slot)


func _add_reward_hint(center: Vector3) -> void:
	var hint := CameraHint.new()
	hint.name = "HighestBloomHint"
	hint.priority = 5
	hint.yaw_degrees = 90.0
	hint.blend_time = 0.9
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(REWARD_SIZE.x + 4.0, 8.0, REWARD_SIZE.y + 4.0)
	shape.shape = box
	shape.position = center
	shape.disabled = true # flipped by _reveal_reward_ground()
	hint.add_child(shape)
	_reward_root.add_child(hint)
	_reward_hint_shape = shape


func _reveal_reward_ground() -> void:
	_reward_root.visible = true
	if _reward_shape != null:
		_reward_shape.disabled = false
	if _reward_hint_shape != null:
		_reward_hint_shape.disabled = false
	print("RISE %s" % JSON.stringify({"phase": "reward_ground_solid"}))
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_reward_root, "position:y", 0.0, REWARD_RISE_DURATION)


# --- Petals -------------------------------------------------------------

func _build_petals() -> void:
	_petals = GPUParticles3D.new()
	_petals.name = "PetalDrift"
	_petals.emitting = false
	_petals.amount = 40
	_petals.lifetime = 5.0
	_petals.one_shot = false
	_petals.position = PETAL_EMIT_POS

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 60.0
	mat.gravity = Vector3(0.0, -0.3, 0.0)
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.6
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(20.0, 2.0, 20.0)
	mat.scale_min = 0.15
	mat.scale_max = 0.3
	_petals.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	var petal_mat := StandardMaterial3D.new()
	petal_mat.albedo_color = PETAL_COLOR
	petal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	petal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = petal_mat
	_petals.draw_pass_1 = quad

	_world.add_child(_petals)


func _start_petals() -> void:
	_petals.emitting = true
	print("RISE %s" % JSON.stringify({"phase": "petals"}))


func _stop_petals() -> void:
	_petals.emitting = false
