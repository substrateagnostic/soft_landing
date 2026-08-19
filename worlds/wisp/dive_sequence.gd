class_name DiveSequence
extends Node3D
## DiveSequence — Wisp's one-time transformative body-function: THE DIVE
## (ROADMAP.md M3, docs/design/world-cards/wisp.md's "signature function").
## At 10/10 dreams returned, Wisp exhales one long sigh and settles gently
## down into the lake; the water rises softly and the shoreline floods into
## new routes — floating cushion-pads and a small islet, previously out of
## reach. Architecture deliberately mirrors worlds/bramble/rollover_
## sequence.gd (READ ONLY reference; this file is a from-scratch sibling,
## not an edit of that one) — same trigger contract, same cinematic-camera/
## letterbox vocabulary (duplicated in, per the task brief: generalizing it
## into core is an M4 card, not tonight's), same bubble-lift-before-anything-
## moves safety rule, same "build hidden once, reveal by flip" convention for
## permanent world geometry.
##
## Trigger: GameState.world_completed("wisp") -- WorldBase already fires this
## the moment all 10 dreamlings return (see worlds/common/world_base.gd
## _check_completion), and GameState persists dreamlings["wisp"].completed,
## so "once per save" falls straight out of that signal exactly the way
## rollover_sequence.gd's own header documents for Bramble. --dive
## (Harness.flags) force-arms the sequence ~3 s after load regardless of
## dream count, dev/capture only (DIVE {"phase":"start","forced":true}).
##
## Safety: EVERY connected player is bubble-lifted (core/rescue/
## bubble_effect.tscn, the same shared rescue/warp visual vocabulary
## rollover_sequence.gd already reuses) to a SAFE, ALREADY-SOLID shore point
## before anything moves. Unlike Bramble's far-meadow reveal (which drops
## players onto BRAND NEW ground and therefore has to race collision-enable
## against the bubble landing), Wisp's landing point is the world's
## pre-existing Shore slab — solid from the moment the world loads — so
## there is no equivalent race to avoid here: nobody is ever near the
## flooding water when it rises. "Shallow fiction" floor (task brief): the
## rising water only ever covers previously-open LAKE surface (LAKE_CENTER/
## LAKE_SIZE, worlds/wisp/wisp.gd), never the Shore slab itself — the new
## cushion/islet route is placed entirely inside the lake's own footprint,
## clear of the shore boundary, so "shore stays dry" holds by construction,
## not by timing luck.

signal dive_started
signal dive_finished

const BUBBLE_SCENE: PackedScene = preload("res://core/rescue/bubble_effect.tscn")

# --- Cinematic camera (machinery generalized into core/cinematic/
# cine_sequence.gd -- the M4 card that worlds/bramble/rollover_sequence.gd
# and this file's own header both flagged as "duplicated... an M4 card, not
# tonight's"; docs/verify/wisp-giant-VERIFY.md's own note is now stale in
# that one respect). Wide: whale + lake in one frame. Dolly: slow follow
# DOWN as he settles. Push: pans west to the newly-flooded shore route +
# islet. Only this world's own waypoints stay here. -----------------
const CINE_WIDE_POS: Vector3 = Vector3(25.0, 50.0, 110.0)
const CINE_WIDE_LOOK: Vector3 = Vector3(30.0, 8.0, 0.0)
const CINE_DESCEND_POS: Vector3 = Vector3(45.0, 30.0, 78.0)
const CINE_DESCEND_LOOK: Vector3 = Vector3(40.0, 1.0, 0.0)
const CINE_ROUTES_POS: Vector3 = Vector3(-40.0, 24.0, 44.0)
const CINE_ROUTES_LOOK: Vector3 = Vector3(-32.0, 3.0, 16.0)
const CINE_TAIL: float = 3.0 # seconds held on the new routes after they open

# --- Whale settle ("he exhales... settles gently down into the lake") ------
const WHALE_DESCEND_DURATION: float = 8.0 # brief: "~8s"
const WHALE_SETTLE_DROP: float = 9.0 # meters -- "half-submerged final pose"
const WHALE_SETTLE_AMPLITUDE: float = 0.3 # residual breath after settling (D25's own "±0.3m drift budget" language)
const FORCED_DELAY: float = 3.0
const BUBBLE_DURATION: float = 4.0 # slower/more majestic than the rescue default (2.5s) -- "gently, hugely" (rollover_sequence.gd's own phrase, applies equally here)
const BUBBLE_LANDING_SPACING: float = 1.4 # two players never land on the exact same point

# Safe, already-solid shore point (worlds/wisp/wisp.gd SHORE_CENTER/
# SHORE_SIZE covers x:-87..-55, z:-23..23) -- clear of HomeDoor (-78,0,1),
# both reed patches, every dressing prop, and the lily-chain start, checked
# against wisp.gd's own const block by >=6m in every case.
const DIVE_LANDING: Vector3 = Vector3(-72.0, 0.5, -6.0)

# --- Flood route: previously-open lake surface (wisp.gd LAKE_CENTER=(-21,0),
# LAKE_SIZE=(68,40) -> x:-55..13, z:-20..20) floods into a hop-chain of
# cushion-pads leading to a new islet. Explicit authored waypoints (bramble
# ascent-path convention: exact geometry, not a generic loop, once a route
# has to thread a specific, checked-by-hand path) rather than the
# zigzag-loop wisp.gd's own main lily chain uses, since this route is short
# (5 pads) and needs to both start right at the shore edge and end at a
# specific islet footprint. Every consecutive edge-to-edge gap (radius 1.7m
# per cushion) is well under the brief's 3.5m single-jump-reach cap (checked
# by hand: 2.0/2.0/2.4/1.5m shore->4, then <2m onward to the islet) --
# see docs/verify/wisp-giant-VERIFY.md for the full gap table.
const FLOOD_CUSHION_RADIUS: float = 1.7
const FLOOD_CUSHION_THICKNESS: float = 0.3
const FLOOD_CUSHION_BOB_AMPLITUDE: float = 0.2
const FLOOD_CUSHION_BOB_PERIOD: float = 3.2
const FLOOD_CUSHION_POSITIONS: Array[Vector3] = [
	Vector3(-53.0, 0.0, 12.0), # 1.7m off the shore boundary (x=-55) -- an easy first hop straight off dry ground
	Vector3(-48.5, 0.0, 15.0),
	Vector3(-43.5, 0.0, 13.0),
	Vector3(-38.5, 0.0, 16.0),
	Vector3(-34.0, 0.0, 14.0),
]
# Blush / cream / sage rotation (task brief's own palette words), pulled
# from colors already proven elsewhere in this world/its siblings: blush
# horizon D9A5B3 (world card's own house-sky color), cream F5F2E8 (bramble's
# COLOR_MILK), sage-grey 8FA0AE (wisp's own REED_TINT_BASE).
const FLOOD_CUSHION_COLORS: Array[Color] = [
	Color("D9A5B3"), Color("F5F2E8"), Color("8FA0AE"), Color("D9A5B3"), Color("F5F2E8"),
]

const ISLET_CENTER: Vector2 = Vector2(-27.0, 15.5) # (x, z) -- well inside the lake's x:-55..13 / z:-20..20 footprint
const ISLET_SIZE: Vector2 = Vector2(8.0, 8.0)
const ISLET_TOP_Y: float = 0.4
const ISLET_THICKNESS: float = 1.0
const COLOR_ISLET: Color = Color("6E8F6A") # moss -- "small cozy platform", distinct from the lake's dusk-blue/silver palette
const COLOR_ISLET_TINT_B: Color = Color("8C9463") # near-neighbor pair for the ground_patches shader (D22 recipe convention)

# Islet dressing (task brief: "2-3 props from the existing Meshy set --
# moon_daisy/stone_soft/lantern"), positions checked by hand against
# ISLET_CENTER +/- ISLET_SIZE*0.5 (x:-31..-23, z:11.5..19.5) and spaced
# >=2m apart.
const ISLET_STONE_SOFT_POS: Vector3 = Vector3(-29.0, 0.0, 13.0)
const ISLET_STONE_SOFT_HEIGHT: float = 0.7 # tools/meshy/manifest.json target_height_hint
const ISLET_STONE_SOFT_COLLISION_RADIUS: float = 0.35 # matches wisp.gd's own STONE_SOFT_COLLISION_RADIUS
const ISLET_MOON_DAISY_POS: Vector3 = Vector3(-25.5, 0.0, 17.0)
const ISLET_MOON_DAISY_HEIGHT: float = 0.4
const ISLET_LANTERN_POS: Vector3 = Vector3(-27.5, 0.0, 18.0)
const ISLET_LANTERN_HEIGHT: float = 0.5

const WATER_RISE_HEIGHT: float = 1.8 # meters -- brief: "~1.5-2m"
const WATER_RISE_DURATION: float = 4.0
const FLOOD_SUBMERGE_OFFSET: float = -2.2 # the whole flood-route group starts this far below its final rest, "underwater," before the reveal

var _world: Node3D = null
var _whale: WhaleDrift = null
var _lake_surface: MeshInstance3D = null
var _lake_surface_rest_y: float = 0.0
var _whale_rest_y: float = 0.0

var _flood_route_root: Node3D = null
var _played: bool = false

## core/cinematic/cine_sequence.gd (M4 card) -- owns the letterbox +
## cine-camera machinery; this file only supplies waypoints (CINE_* consts
## above) via begin()/dolly_to()/push_to()/end().
var _cine: CineSequence = null


func setup(world: Node3D, whale: WhaleDrift, lake_surface: MeshInstance3D) -> void:
	_world = world
	_whale = whale
	_lake_surface = lake_surface


func _ready() -> void:
	_whale_rest_y = _whale.position.y # still the un-ticked rest value at this point in boot (see wisp.gd _build_dive()'s own ordering note)
	_lake_surface_rest_y = _lake_surface.position.y
	_cine = CineSequence.new()
	_cine.name = "DiveCine"
	add_child(_cine)
	_cine.setup(_world, "DiveCineCamera", "DiveLetterbox")
	_build_flood_route_geometry() # built once, hidden+disabled -- reveal is a visibility/collision flip + a rise tween, never a rebuild

	if GameState.is_world_completed("wisp"):
		_apply_already_dived_state()
		return

	GameState.world_completed.connect(_on_world_completed)
	if Harness.flag("dive", false):
		var timer: SceneTreeTimer = get_tree().create_timer(FORCED_DELAY)
		timer.timeout.connect(_on_forced_trigger)


func _on_world_completed(world_id: String) -> void:
	if world_id != "wisp" or _played:
		return
	_play_sequence(false)


func _on_forced_trigger() -> void:
	if _played:
		return
	_play_sequence(true)


func _play_sequence(forced: bool) -> void:
	_played = true
	print("DIVE %s" % JSON.stringify({"phase": "start", "forced": forced}))
	dive_started.emit()
	AudioManager.play_sfx_overlay("giant_rumble") # audio pass 3: the ground remembering it's alive -- overlay so bubble_catch (fired moments later, same frame) doesn't cut it off
	# Praise moved to phase=end — it lands on the payoff, not the windup (B12: C1-S3).

	_cine.begin(CINE_WIDE_POS, CINE_WIDE_LOOK)
	_cine.dolly_to(CINE_DESCEND_POS, CINE_DESCEND_LOOK, WHALE_DESCEND_DURATION)
	_bubble_all_players() # every connected player, off the whale and safe, BEFORE it moves at all
	_whale.begin_settle(_whale_rest_y - WHALE_SETTLE_DROP, WHALE_DESCEND_DURATION, WHALE_SETTLE_AMPLITUDE)

	var descend_timer: SceneTreeTimer = get_tree().create_timer(WHALE_DESCEND_DURATION)
	await descend_timer.timeout
	AudioManager.play_sfx("giant_yawn_sigh") # audio pass 3: the whale settle
	print("DIVE %s" % JSON.stringify({"phase": "settled"}))

	_cine.push_to(CINE_ROUTES_POS, CINE_ROUTES_LOOK, WATER_RISE_DURATION * 0.9)
	_reveal_flood_route() # collision solid FIRST, immediately -- rollover_sequence.gd's own lesson, applied here even though (per the header note) nothing is actually racing it this time
	AudioManager.play_sfx_overlay("water_rise_shimmer") # audio pass 3: the flood beat -- overlay so it layers under giant_yawn_sigh's settle beat instead of cutting it off
	_tween_flood_route_rise()

	var rise_timer: SceneTreeTimer = get_tree().create_timer(WATER_RISE_DURATION)
	await rise_timer.timeout
	print("DIVE %s" % JSON.stringify({"phase": "routes_open"}))

	var tail_timer: SceneTreeTimer = get_tree().create_timer(CINE_TAIL)
	await tail_timer.timeout
	_cine.end()

	TheMoon.say("world_complete") # praise lands on the payoff (B12: C1-S3)
	print("DIVE %s" % JSON.stringify({"phase": "end", "forced": forced}))
	dive_finished.emit()


## Reuses the exact rescue/warp visual vocabulary (core/rescue/
## bubble_effect.gd) rather than any bespoke lift -- rollover_sequence.gd's
## own "never a custom rescue" convention, applied identically here.
## Unconditional (every connected player, wherever they stand): nothing can
## ever be disturbed out from under someone if no one is ever left on the
## whale in the first place.
func _bubble_all_players() -> void:
	var offset: float = 0.0
	for player: Node in get_tree().get_nodes_in_group("players"):
		if not (player is PlayerBody):
			continue
		var bubble: BubbleEffect = BUBBLE_SCENE.instantiate()
		get_tree().current_scene.add_child(bubble)
		var landing: Vector3 = DIVE_LANDING + Vector3(offset, 0.0, 0.0)
		offset += BUBBLE_LANDING_SPACING
		bubble.play(player as PlayerBody, landing, "bubble_catch", BUBBLE_DURATION)


func _apply_already_dived_state() -> void:
	_whale.settle_immediately(_whale_rest_y - WHALE_SETTLE_DROP, WHALE_SETTLE_AMPLITUDE)
	_lake_surface.position.y = _lake_surface_rest_y + WATER_RISE_HEIGHT
	_flood_route_root.position.y = 0.0
	_reveal_flood_route()


# --- Flood route rise --------------------------------------------------------

## The whole group rises together (a single parent-Y tween), which correctly
## carries every AnimatableBody3D cushion via the exact same sync_to_physics-
## composes-parent-motion mechanism worlds/wisp/whale_drift.gd's own header
## documents (and worlds/bramble/rollover_sequence.gd's tail/dorsal-slide
## nesting note before it) -- no per-cushion tween needed. The islet's
## StaticBody3D rides along too: nothing stands on it while it moves (every
## player is on the shore for the whole sequence), so the usual "prefer
## AnimatableBody3D for anything a character rides while it's actively
## moving" concern doesn't apply here -- it only needs to be correctly
## positioned once the tween finishes, which a moved StaticBody3D is.
func _tween_flood_route_rise() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	tween.tween_property(_flood_route_root, "position:y", 0.0, WATER_RISE_DURATION)
	tween.tween_property(_lake_surface, "position:y", _lake_surface_rest_y + WATER_RISE_HEIGHT, WATER_RISE_DURATION)


func _reveal_flood_route() -> void:
	_flood_route_root.visible = true
	for shape: CollisionShape3D in _collect_collision_shapes(_flood_route_root):
		shape.disabled = false


func _collect_collision_shapes(node: Node) -> Array[CollisionShape3D]:
	var found: Array[CollisionShape3D] = []
	for child: Node in node.get_children():
		if child is CollisionShape3D:
			found.append(child as CollisionShape3D)
		found.append_array(_collect_collision_shapes(child))
	return found


# ---------------------------------------------------------------------------
# Geometry -- built once at _ready (hidden/disabled, submerged), revealed by
# flipping visibility + collision and tweening the group's own Y offset up
# to 0, matching SnoreGeyser's/rollover_sequence.gd's own "toggle, never
# rebuild" convention.
# ---------------------------------------------------------------------------

func _build_flood_route_geometry() -> void:
	_flood_route_root = Node3D.new()
	_flood_route_root.name = "FloodRoute"
	_flood_route_root.visible = false
	_flood_route_root.position.y = FLOOD_SUBMERGE_OFFSET
	_world.add_child(_flood_route_root)

	_build_flood_cushions()
	_build_islet()
	_add_camera_hint_flood_route()
	_add_camera_hint_islet()

	for shape: CollisionShape3D in _collect_collision_shapes(_flood_route_root):
		shape.disabled = true


func _build_flood_cushions() -> void:
	for i: int in FLOOD_CUSHION_POSITIONS.size():
		var cushion := LilyPad.new()
		cushion.name = "FloodCushion_%d" % i
		cushion.radius = FLOOD_CUSHION_RADIUS
		cushion.thickness = FLOOD_CUSHION_THICKNESS
		cushion.amplitude = FLOOD_CUSHION_BOB_AMPLITUDE
		cushion.period = FLOOD_CUSHION_BOB_PERIOD
		cushion.phase_offset = float(i) * (TAU / float(FLOOD_CUSHION_POSITIONS.size()))
		cushion.pad_color = FLOOD_CUSHION_COLORS[i % FLOOD_CUSHION_COLORS.size()]
		cushion.position = FLOOD_CUSHION_POSITIONS[i]
		_flood_route_root.add_child(cushion)


func _build_islet() -> void:
	_add_ground_slab("Islet", ISLET_SIZE, ISLET_TOP_Y, ISLET_THICKNESS, COLOR_ISLET, ISLET_CENTER)
	var mat: ShaderMaterial = _ground_patch_material(COLOR_ISLET, COLOR_ISLET_TINT_B)
	(_flood_route_root.get_node("Islet") as MeshInstance3D).set_surface_override_material(0, mat)

	_add_dressing_prop("IsletStoneSoft", "stone_soft", ISLET_STONE_SOFT_HEIGHT, ISLET_STONE_SOFT_POS)
	_add_prop_cylinder_collision(ISLET_STONE_SOFT_POS, ISLET_STONE_SOFT_COLLISION_RADIUS, ISLET_STONE_SOFT_HEIGHT)
	_add_dressing_prop("IsletMoonDaisy", "moon_daisy", ISLET_MOON_DAISY_HEIGHT, ISLET_MOON_DAISY_POS)
	_add_dressing_prop("IsletLantern", "lantern", ISLET_LANTERN_HEIGHT, ISLET_LANTERN_POS)


func _add_ground_slab(slab_name: String, size: Vector2, top_y: float, thickness: float, color: Color, xz_center: Vector2) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, thickness, size.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat

	var center: Vector3 = Vector3(xz_center.x, top_y - thickness * 0.5, xz_center.y)

	var visual := MeshInstance3D.new()
	visual.name = slab_name
	visual.mesh = mesh
	visual.position = center
	_flood_route_root.add_child(visual)

	var body := StaticBody3D.new()
	body.name = slab_name + "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = mesh.size
	shape.shape = box_shape
	shape.position = center
	body.add_child(shape)
	_flood_route_root.add_child(body)


func _ground_patch_material(tint_a: Color, tint_b: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ground_patches.gdshader") as Shader
	mat.set_shader_parameter("tint_a", tint_a)
	mat.set_shader_parameter("tint_b", tint_b)
	return mat


## Anchor + ModelSlot only (no primitive fallback mesh) -- matches rollover_
## sequence.gd's own _add_meshy_prop() convention, safe here because all
## three prop GLBs (stone_soft/moon_daisy/lantern) are already generated and
## on disk (confirmed via assets/models/meshy/generated/ listing), unlike
## wisp.gd's own _add_dressing_prop() which additionally builds a primitive
## as a belt-and-suspenders fallback for props that might not have GLBs yet.
func _add_dressing_prop(anchor_name: String, model_id: String, target_height: float, prop_position: Vector3) -> void:
	var anchor := Node3D.new()
	anchor.name = anchor_name
	anchor.position = prop_position
	_flood_route_root.add_child(anchor)

	var slot := ModelSlot.new()
	slot.name = "ModelSlot"
	slot.model_id = model_id
	slot.target_height = target_height
	anchor.add_child(slot)


## Matches wisp.gd's own _add_prop_cylinder_collision() exactly (duplicated,
## not called cross-file, since wisp.gd's version is a private/unexported
## method on the Wisp script, not a shared utility) -- "only stump_door +
## stone_soft + soft_pine get simple static collision cylinders" convention,
## applied here to the islet's own stone_soft.
func _add_prop_cylinder_collision(prop_position: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = "PropCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.position = prop_position + Vector3(0.0, height * 0.5, 0.0)
	body.add_child(shape)
	_flood_route_root.add_child(body)


func _add_camera_hint_flood_route() -> void:
	var hint := CameraHint.new()
	hint.name = "FloodRouteHint"
	hint.priority = 3
	hint.yaw_degrees = -90.0 # matches wisp.gd's own convention (0=-Z forward, -90=+X) -- facing further into the world, same as ShoreApproachHint/LakeCrossingHint
	hint.blend_time = 1.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(38.0, 8.0, 12.0)
	shape.shape = box
	shape.position = Vector3(-39.0, 3.0, 15.0)
	shape.disabled = true # flipped by _reveal_flood_route()
	hint.add_child(shape)
	_flood_route_root.add_child(hint)


func _add_camera_hint_islet() -> void:
	var hint := CameraHint.new()
	hint.name = "IsletHint"
	hint.priority = 4
	hint.yaw_degrees = -90.0
	hint.blend_time = 1.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ISLET_SIZE.x + 4.0, 8.0, ISLET_SIZE.y + 4.0)
	shape.shape = box
	shape.position = Vector3(ISLET_CENTER.x, 3.0, ISLET_CENTER.y)
	shape.disabled = true # flipped by _reveal_flood_route()
	hint.add_child(shape)
	_flood_route_root.add_child(hint)
