class_name Wisp
extends WorldBase
## Wisp — the third world (docs/design/world-cards/wisp.md): a whale the
## size of a weather system, dozing in mid-air just above a moonlit
## mountain lake. Layout along +X like Bramble, shore at -X: shore spawn
## (reeds) -> lily-pad hop chain across the lake -> flipper ledge -> belly
## shelf -> dorsal slide crest -> blowhole/head (the DreamDoor). Ten
## dreamlings placed per the D12 dense-cadence rule (see
## docs/verify/world-wisp-VERIFY.md for the full d01-d10 route table).
## Grey-box: primitive meshes, flat StandardMaterial3D colors, palette
## hexes from the world card verbatim.
##
## Architecture note: "the whale is ONE AnimatableBody3D group so
## everything on it rides together" (world card) is implemented as ONE
## compound physics body, `_whale` (a WhaleDrift), whose direct
## CollisionShape3D children are the tail/body/head mounds, flipper ledge,
## belly shelf, dorsal crest and the blowhole rim -- one body, one velocity,
## every rider carried identically regardless of which shape they stand on.
## The two exceptions need their OWN nested AnimatableBody3D (still a child
## of `_whale`, so they still inherit its drift via the engine's normal
## transform composition + `sync_to_physics` transform-diff, verified
## against worlds/bramble/breathing_chest.gd's proven pattern): the dorsal
## slide needs its own low-friction PhysicsMaterial (friction is a
## per-BODY property in Godot, so it can't share `_whale`'s body without
## making the whole whale slippery), and the tail seesaw needs its own
## local rotation. Lily pads and the water spout are NOT part of the whale
## group -- they float independently on the lake / stand on the moving head
## respectively (the spout is a plain Area3D, so it rides `_whale`'s motion
## for free the moment it's parented under it, no sync flag needed).

const DREAMLING_SCENE: PackedScene = preload("res://worlds/common/dreamling.tscn")
const DREAM_DOOR_SCENE: PackedScene = preload("res://worlds/common/dream_door.tscn")

# --- Palette (docs/design/world-cards/wisp.md, verbatim hexes) -----------
const COLOR_LAKE: Color = Color("22304F") # deep dusk blue
const COLOR_HIDE: Color = Color("C9D4E4") # silver, whale hide
const COLOR_EMISSIVE: Color = Color("9FE8E0") # pale cyan, emissives/spouts
const COLOR_SHORE: Color = Color("5E6B7A") # wet-stone grey, shore rocks

# --- Spawns (shore edge, arriving from the fort direction, facing +X) ----
const SPAWN_PIP: Vector3 = Vector3(-72.0, 0.5, 0.0)
const SPAWN_OTTO: Vector3 = Vector3(-74.0, 0.5, 2.0)

# --- Shore ------------------------------------------------------------
const SHORE_SIZE: Vector2 = Vector2(32.0, 46.0)
const SHORE_CENTER: Vector2 = Vector2(-71.0, 0.0)
const SHORE_TOP_Y: float = 0.0
const SHORE_THICKNESS: float = 1.0

# --- Moat / void (beyond the shore ring; same pattern as bramble's moat:
# sunk below RESCUE_FLOOR_Y so it can never be a stuck apron) -------------
const MOAT_SIZE: Vector2 = Vector2(260.0, 150.0)
const MOAT_TOP_Y: float = -9.0
const MOAT_THICKNESS: float = 1.0
const RESCUE_FLOOR_Y: float = -8.0

# --- Lake: a translucent surface plane (visual only, no collision) over a
# walkable submerged bed (knee-deep, y ~ -0.4) so falling between lily pads
# is never a pit -- you wade to a pad edge and climb (SHORE at y=0.0 abuts
# the bed at x=-55 exactly: a 0.4 m step, comfortably inside floor_snap). --
const LAKE_SIZE: Vector2 = Vector2(68.0, 40.0)
const LAKE_CENTER: Vector2 = Vector2(-21.0, 0.0)
const LAKE_PLANE_Y: float = 0.05
const LAKE_BED_TOP_Y: float = -0.4
const LAKE_BED_THICKNESS: float = 1.0

# --- Lily-pad hop chain (8-10 pads, >=1.6 m radius, edge gaps 1.2-2.0 m).
# LILY_STEP is the exact center-to-center distance (2*radius + target gap),
# so the zigzag heading can wander in Z without ever changing the actual
# edge gap -- computed, not eyeballed (bramble's _sphere_surface_y lesson,
# applied here to spacing instead of height). ----------------------------
const LILY_COUNT: int = 9
const LILY_RADIUS: float = 1.8
const LILY_THICKNESS: float = 0.3
const LILY_GAP: float = 1.6
const LILY_STEP: float = 2.0 * LILY_RADIUS + LILY_GAP # 5.2 m
const LILY_START: Vector3 = Vector3(-51.0, 0.0, -3.0)
const LILY_ZIGZAG_DEGREES: float = 14.0
const LILY_BOB_AMPLITUDE: float = 0.2
const LILY_BOB_PERIOD: float = 3.5

# --- Whale anatomy, along +X (tail -> body/dorsal crest -> head) ---------
const WHALE_DRIFT_AMPLITUDE: float = 2.5
const WHALE_DRIFT_PERIOD: float = 20.0

const TAIL_CENTER: Vector3 = Vector3(7.0, -3.0, 0.0)
const TAIL_RADIUS: float = 9.0 # top = 6.0 m

const BODY_CENTER: Vector3 = Vector3(34.0, -2.0, 0.0)
const BODY_RADIUS: float = 16.0 # top = 14.0 m -- "back crest ~14 m at rest"

const HEAD_CENTER: Vector3 = Vector3(73.0, -6.0, 0.0)
const HEAD_RADIUS: float = 18.0 # top = 12.0 m

# Flipper ledge (d04): anchored low on the tail mound's lake-facing flank
# so the vertical gap to it, timed at the drift's low point, is a forgiving
# ~0.9-1.2 m jump from the lake bed/last lily pad -- and a clear ~5.5-6 m
# (must wait) at the drift's high point. "Timing a slow, forgiving
# elevator," per the world card.
const FLIPPER_LEDGE_ANCHOR_X: float = 0.0
const FLIPPER_LEDGE_ANCHOR_Z: float = 0.0
const FLIPPER_LEDGE_HEIGHT_ABOVE_ANCHOR: float = 0.3
const FLIPPER_LEDGE_SIZE: Vector3 = Vector3(4.0, 0.5, 4.0)

# Belly shelf (d05, "open"): a generous mid-height plateau on the body
# mound's flank, reached by continuing the climb from the flipper ledge.
const BELLY_SHELF_ANCHOR_X: float = 24.0
const BELLY_SHELF_ANCHOR_Z: float = 6.0
const BELLY_SHELF_HEIGHT_ABOVE_ANCHOR: float = 0.3
const BELLY_SHELF_SIZE: Vector3 = Vector3(5.0, 0.5, 5.0)

# Dorsal crest (d08): the body mound's exact peak, ~14 m at rest.
const DORSAL_CREST_HEIGHT_ABOVE_ANCHOR: float = 0.3
const DORSAL_CREST_SIZE: Vector3 = Vector3(3.5, 0.5, 3.5)

# Dorsal slide: crest -> belly shelf, low-friction, always lands safely on
# the shelf (never into void), per the world card.
const DORSAL_SLIDE_WIDTH: float = 3.0
const DORSAL_SLIDE_THICKNESS: float = 0.4
const DORSAL_SLIDE_FRICTION: float = 0.05
const DORSAL_SLIDE_LANDING_CLEARANCE: float = 0.05

# Tail seesaw: a gentle bonus rocking bridge near the tail, offset from the
# flipper-ledge route (mirrors bramble's dual paw-ramp Z-offset pattern).
# Amplitude/length tuned together so no end ever swings more than ~0.5 m.
const TAIL_SEESAW_PIVOT: Vector3 = Vector3(9.0, 2.3, -8.0)
const TAIL_SEESAW_LENGTH: float = 8.0

# Blowhole (the DreamDoor) + its rim bump, mirroring bramble's ear pattern.
const BLOWHOLE_ANCHOR_X: float = 73.0
const BLOWHOLE_ANCHOR_Z: float = 6.0
const BLOWHOLE_BUMP_HEIGHT: float = 1.3
const BLOWHOLE_BUMP_RADIUS: float = 1.6

# Water spout (d07 rides it): 14 m tall, erupts on the whale's own breath
# cycle (same period as WHALE_DRIFT_PERIOD).
const WATER_SPOUT_ANCHOR_X: float = 79.0
const WATER_SPOUT_ANCHOR_Z: float = -5.0
const WATER_SPOUT_HEIGHT: float = 14.0

# --- Wisp giant treatment (ROADMAP M3): the real plush whale model replaces
# the primitive Tail/Body/Head mounds as WHAT YOU SEE, while every mound's
# collision (plus the shelves/ledges/rim built on top of them) stays exactly
# where it always was -- bramble_bear_rig's precedent (worlds/bramble/
# bramble.gd _build_bear_shell()): oversized, non-mesh-hugging collision the
# visible giant merely stands generously inside of, not a re-derivation.
# wisp_whale_b.glb's own local AABB (measured via tools/meshy/preview_model.
# tscn, evidence/stills/m3_wisp/preview) is (x=0.873, y=0.544, z=1.906) --
# long axis is local Z, so a 90 deg yaw maps it to world +X exactly the same
# way bramble's BEAR_SHELL_YAW_DEGREES=90 maps the rig's local +Z forward to
# world +X (that file's own header note, confirmed by still there; confirmed
# independently by still here -- see WHALE_SHELL_VERIFY notes in
# docs/verify/wisp-giant-VERIFY.md). Anchored at the TAIL/HEAD span's
# midpoint ((7+73)/2=40) so the ~88 m model (target_height * z/y ratio)
# roughly envelops the old ~93 m mound chain without moving a single
# existing dreamling/shelf/ledge coordinate.
const WHALE_SHELL_POSITION: Vector3 = Vector3(40.0, -3.0, 0.0)
# v2 (still-corrected, evidence/stills/m3_wisp/whale_check/shot_30.png): a
# 90 deg yaw put the model's NOSE toward the shore/tail end (world -X) and
# its FLUKES toward the blowhole/head end (world +X) -- backwards. -90 deg
# fixes it (confirmed by the follow-up still): local +Z is the model's
# FLUKE end, not its nose end, opposite of bramble's own rig.
const WHALE_SHELL_YAW_DEGREES: float = -90.0
const WHALE_SHELL_TARGET_HEIGHT: float = 25.0 # meters -- length works out to ~88 m at this GLB's aspect ratio

# Shore reeds (tall thin boxes; d09 hides in the first patch).
const REED_PATCH_1_X: float = -68.0
const REED_PATCH_1_Z: float = 8.0
const REED_PATCH_2_X: float = -78.0
const REED_PATCH_2_Z: float = -10.0
const REED_PATCH_SPREAD: float = 1.8
const REED_BLADE_HEIGHT: float = 1.5

# --- Ambient warm fill + softer wind-swayed reeds (D22 graphics-v2,
# visual-only): the polish note on the original box-blade reeds was
# "too dark/spiky" (COLOR_SHORE, a grey-brown wet-stone tone, on stiff
# unlit boxes) -- swapped for wind_sway.gdshader blades in a lighter,
# softer tint, same two patch locations/footprint. ------------------------
const REED_TINT_BASE: Color = Color("8FA0AE") # lighter than COLOR_SHORE, still cool
const REED_TINT_TIP: Color = Color("D8E4EC") # near-white tip catches the moon key
const REED_DENSITY: int = 26
const SHORE_FILL_POSITION: Vector3 = Vector3(-70.0, 1.4, 4.0) # recipe: "warm fill lights at practicals ... wisp shore"
const SHORE_FILL_COLOR: Color = Color("F2C879")
# ROUND 2 (director's note 1, "Same fix wherever grass_field is used (wisp
# reeds included)"): wider than the original 0.05 needle-thin override,
# matching GrassField's own wider ROUND 2 default -- plus the class-wide
# backface-normal fix (assets/shaders/wind_sway.gdshader) and tapered-quad
# blade shape (core/env/grass_field.gd) apply here automatically.
const REED_BLADE_WIDTH: float = 0.09
# Note 2 ("flat single-color ground"): cool shore <-> a warm sand hint.
const GROUND_TINT_B: Color = Color("8C8570")

const DREAMKEEPER_SCENE: PackedScene = preload("res://worlds/common/dreamkeeper.tscn")
const DREAMKEEPER_DATA_PATH_FORMAT: String = "res://data/dreamkeepers/%s.json"

# --- Dressing M2 props (assets/models/meshy/generated/, tools/meshy/
# manifest.json target_height_hint values). All scattered across the shore
# ring (SHORE_CENTER, SHORE_SIZE), clear of SPAWN_PIP/SPAWN_OTTO, HomeDoor,
# both reed patches, the lily chain start, and every d0x dreamling position
# by >=2 m -- checked against this file's own const/dreamling positions.
# Nothing here carries collision except the two stone_soft + the stump_door
# (per the brief), so nothing else can physically block a route. -----------
const STONE_SOFT_HEIGHT: float = 0.7
const STONE_SOFT_COLLISION_RADIUS: float = 0.35
const STONE_SOFT_POSITIONS: Array[Vector3] = [
	Vector3(-71.0, 0.0, 13.0), # north of ReedPatch1, "reed-adjacent"
	Vector3(-83.0, 0.0, -6.0), # near ReedPatch2
]
const STUMP_DOOR_HEIGHT: float = 0.8
const STUMP_DOOR_COLLISION_RADIUS: float = 0.4
const STUMP_DOOR_POSITION: Vector3 = Vector3(-84.0, 0.0, 9.0) # on the shore, north of HomeDoor
const CLOVER_TUFT_HEIGHT: float = 0.3
const CLOVER_TUFT_POSITIONS: Array[Vector3] = [
	Vector3(-69.0, 0.0, 10.5), # reed-adjacent (ReedPatch1)
	Vector3(-79.5, 0.0, -8.5), # reed-adjacent (ReedPatch2)
]
const MOON_DAISY_HEIGHT: float = 0.4
const MOON_DAISY_POSITIONS: Array[Vector3] = [
	Vector3(-73.0, 0.0, 5.0),
	Vector3(-66.0, 0.0, -4.0),
	Vector3(-80.0, 0.0, 16.0),
	Vector3(-59.0, 0.0, -18.0),
]
const SEED_PUFF_HEIGHT: float = 0.35
const SEED_PUFF_POSITIONS: Array[Vector3] = [
	Vector3(-77.0, 0.0, 20.0),
	Vector3(-63.0, 0.0, 18.0),
	Vector3(-85.0, 0.0, -18.0),
]

var _whale: WhaleDrift = null
var _water_spout: WaterSpout = null
var _lily_pads: Array[LilyPad] = []
var _flipper_ledge_center: Vector3 = Vector3.ZERO
var _belly_shelf_center: Vector3 = Vector3.ZERO
var _dorsal_crest_center: Vector3 = Vector3.ZERO
var _tail_visual: MeshInstance3D = null
var _body_visual: MeshInstance3D = null
var _head_visual: MeshInstance3D = null


func _ready() -> void:
	_build_shore()
	_build_moat()
	_build_lake()
	_build_reeds()
	_build_lily_chain()
	_build_whale()
	_build_dreamlings()
	_build_camera_hints()
	_build_home_door()
	_build_ambient_lighting()
	_build_dreamkeepers()
	_build_dressing()
	_build_shore_friends() # D28: the Shedd winners (after _build_shore -- terrain-snaps to it)
	_build_dive() # ROADMAP M3 wisp-giant: THE DIVE, looks up _whale/LakeSurface -- after both exist
	_build_dev_camera()
	super._ready()


## Warm practical fill at the shore (recipe: "warm fill lights at
## practicals ... wisp shore") -- wisp had only the cool cyan LakeUnderglow
## before this, no warm source, unlike pillow_fort/marmalade whose porch/
## window lights already existed.
func _build_ambient_lighting() -> void:
	var light := OmniLight3D.new()
	light.name = "ShoreLanternGlow"
	light.light_color = SHORE_FILL_COLOR
	light.light_energy = 0.45
	light.omni_range = 8.0
	light.position = SHORE_FILL_POSITION
	add_child(light)


func world_id() -> String:
	return "wisp"


func spawn_points() -> Dictionary:
	var facing_whale: Basis = Basis.looking_at(Vector3.RIGHT, Vector3.UP) # +X, toward the lake and the whale
	return {
		"pip": Transform3D(facing_whale, SPAWN_PIP),
		"otto": Transform3D(facing_whale, SPAWN_OTTO),
	}


func objective_ids() -> Array[String]:
	return ["d01", "d02", "d03", "d04", "d05", "d06", "d07", "d08", "d09", "d10"] as Array[String]


func rescue_floor_y() -> float:
	return RESCUE_FLOOR_Y


## The way home: a doorframe at the shore edge behind spawn, facing the
## lake/whale, so leaving is always one interact away (worlds are never
## D28 — the Shedd winners ("starfish and penguins", producer, the night
## after the aquarium trip). Two shore friends for Ezra: a plush starfish
## at the waterline that squash-boops when poked (TouchReact via the
## "poke" group — zero bespoke reaction code), and a penguin chick that
## waddles a small patrol and greets kids who come close (ShoreFriend,
## worlds/wisp/shore_friend.gd). Both terrain-snapped to the Shore
## heightfield and swapped to their plush GLBs via ModelSlot.
const STARFISH_POSITION_XZ: Vector2 = Vector2(-57.5, 5.0) # waterline, south of the lily route
const PENGUIN_PATROL_A_XZ: Vector2 = Vector2(-61.0, -6.0)
const PENGUIN_PATROL_B_XZ: Vector2 = Vector2(-65.0, -10.0)


func _build_shore_friends() -> void:
	var starfish_pos: Vector3 = _on_shore(STARFISH_POSITION_XZ)
	var starfish := Node3D.new()
	starfish.name = "StarfishVisual"
	starfish.position = starfish_pos
	add_child(starfish)

	# Placeholder: five flattened coral arms + a center dome, replaced by
	# the plush GLB (starfish_plush) the moment ModelSlot resolves it.
	var arm_mat := StandardMaterial3D.new()
	arm_mat.albedo_color = Color("E8917C") # soft coral
	for i: int in range(5):
		var arm := MeshInstance3D.new()
		arm.name = "StarfishArm%d" % i
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.05
		arm_mesh.height = 0.3
		arm_mesh.material = arm_mat
		arm.mesh = arm_mesh
		var angle: float = TAU * float(i) / 5.0
		arm.position = Vector3(sin(angle) * 0.12, 0.05, cos(angle) * 0.12)
		arm.rotation_degrees = Vector3(90.0, rad_to_deg(angle), 0.0)
		starfish.add_child(arm)
	var center := MeshInstance3D.new()
	center.name = "StarfishCenter"
	var center_mesh := SphereMesh.new()
	center_mesh.radius = 0.09
	center_mesh.height = 0.12
	center_mesh.material = arm_mat
	center.mesh = center_mesh
	center.position = Vector3(0.0, 0.06, 0.0)
	starfish.add_child(center)

	var starfish_slot := ModelSlot.new()
	starfish_slot.name = "StarfishModelSlot"
	starfish_slot.model_id = "starfish_plush"
	starfish_slot.target_height = 0.35
	starfish.add_child(starfish_slot)
	starfish.add_to_group("poke") # world_base auto-attaches TouchReact: squash + boop

	var penguin := ShoreFriend.new()
	penguin.name = "PenguinChick"
	penguin.setup(_on_shore(PENGUIN_PATROL_A_XZ), _on_shore(PENGUIN_PATROL_B_XZ))
	add_child(penguin)


## _on_shore — world position snapped to the Shore heightfield (D27
## terrain), so the friends sit ON the rolling ground, never in or above
## it. Falls back to y=0 if the Shore isn't a TerrainPatch (older saves,
## test scenes).
func _on_shore(xz: Vector2) -> Vector3:
	var y: float = 0.0
	var shore: Node = get_node_or_null("Shore")
	if shore is TerrainPatch:
		y = (shore as TerrainPatch).sample_height(xz.x - SHORE_CENTER.x, xz.y - SHORE_CENTER.y)
	return Vector3(xz.x, y, xz.y)


## gated). Mirrors bramble.gd's HomeDoor exactly.
func _build_home_door() -> void:
	var door := WorldDoor.new()
	door.name = "HomeDoor"
	door.target_world = "pillow_fort"
	door.frame_color = COLOR_HIDE
	door.position = Vector3(SPAWN_PIP.x - 6.0, 0.0, 1.0)
	door.rotation_degrees = Vector3(0.0, 90.0, 0.0) # opening faces the lake/whale (+X)
	door.exit_requested.connect(func() -> void:
		exit_requested_to.emit("pillow_fort")
		exit_requested.emit()
	)
	add_child(door)


# --- Geometry helpers -------------------------------------------------------

## Height of a sphere mound's surface directly above world (x, z); 0 if that
## point is outside the sphere's footprint (bramble.gd's proven helper).
func _sphere_surface_y(center: Vector3, radius: float, x: float, z: float) -> float:
	var dx: float = x - center.x
	var dz: float = z - center.z
	var under_sqrt: float = radius * radius - dx * dx - dz * dz
	if under_sqrt < 0.0:
		return center.y
	return center.y + sqrt(under_sqrt)


func _add_dreamling(id: String, local_position: Vector3, parent: Node3D) -> void:
	var dreamling: Dreamling = DREAMLING_SCENE.instantiate() as Dreamling
	dreamling.name = "Dreamling_" + id
	dreamling.id = id
	dreamling.position = local_position
	parent.add_child(dreamling)


## Static ground slab (bramble.gd's proven helper, verbatim): a MeshInstance3D
## + matching StaticBody3D, both parented to `self` -- used for the shore,
## the moat, and the lake bed, none of which move.
func _add_ground_slab(slab_name: String, size: Vector2, top_y: float, thickness: float, color: Color, xz_center: Vector2 = Vector2.ZERO) -> void:
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
	add_child(visual)

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
	add_child(body)


## D22 graphics-v2 ROUND 2, assets/shaders/ground_patches.gdshader (director's
## note 2): builds a ShaderMaterial pre-loaded with a world's near-neighbor
## tint pair.
func _ground_patch_material(tint_a: Color, tint_b: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ground_patches.gdshader") as Shader
	mat.set_shader_parameter("tint_a", tint_a)
	mat.set_shader_parameter("tint_b", tint_b)
	return mat


func _build_shore() -> void:
	# D27 terrain v1 (bramble's template): the shore rolls softly. Small,
	# crowded space (spawns, two doors, reeds, the lily-chain start) so the
	# amplitude stays 0.3 with pinned discs at both door clearings. The
	# patch's own edge falloff eases to exactly y=0 at its borders, keeping
	# the east edge flush where it meets the lake bed. Coordinates in the
	# disc list are LOCAL to the patch node at SHORE_CENTER.
	var shore := TerrainPatch.new()
	shore.name = "Shore"
	shore.position = Vector3(SHORE_CENTER.x, SHORE_TOP_Y, SHORE_CENTER.y)
	var flat_discs: Array[Vector3] = [
		Vector3(SPAWN_PIP.x - SHORE_CENTER.x - 3.0, 1.0, 7.0), # spawns + HomeDoor clearing
		Vector3(STUMP_DOOR_POSITION.x - SHORE_CENTER.x, STUMP_DOOR_POSITION.z, 3.5), # stump door
	]
	shore.setup(SHORE_SIZE, 0.3, 11.0, 9, flat_discs, 6.0, TerrainPatch.DEFAULT_RESOLUTION, 9.5)
	add_child(shore)
	(get_node("Shore") as MeshInstance3D).set_surface_override_material(0, _ground_patch_material(COLOR_SHORE, GROUND_TINT_B))


## Below RESCUE_FLOOR_Y on purpose (bramble's moat lesson): stepping off the
## shore, off the far side of the lake, or past the whale's ends must always
## end in the Soft Landing, never on a walkable apron a jump can't escape.
func _build_moat() -> void:
	_add_ground_slab("Moat", MOAT_SIZE, MOAT_TOP_Y, MOAT_THICKNESS, COLOR_LAKE)


func _build_lake() -> void:
	_add_ground_slab("LakeBed", LAKE_SIZE, LAKE_BED_TOP_Y, LAKE_BED_THICKNESS, COLOR_SHORE, LAKE_CENTER)
	(get_node("LakeBed") as MeshInstance3D).set_surface_override_material(0, _ground_patch_material(COLOR_SHORE, GROUND_TINT_B))
	_add_lake_plane()
	_add_lake_underglow()


## Visual only, no collision -- the walkable bed is LakeBed above it.
## D22 / recipes "Water (Wisp's lake)": stylized absorption-based water
## (assets/shaders/stylized_water.gdshader) instead of a flat translucent
## plane -- depth-based color, a foam edge that appears for free wherever
## the whale mounds break the surface (foam is a function of the plane-to-
## scene depth difference, not hardcoded per-object), gentle vertex waves.
func _add_lake_plane() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = LAKE_SIZE
	mesh.subdivide_width = 32 # enough vertex density for the wave displacement to read
	mesh.subdivide_depth = 32

	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/stylized_water.gdshader") as Shader
	mat.set_shader_parameter("shallow_color", Color(0.20, 0.30, 0.42))
	mat.set_shader_parameter("deep_color", COLOR_LAKE)
	mat.set_shader_parameter("foam_color", COLOR_HIDE)
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "LakeSurface"
	visual.mesh = mesh
	visual.position = Vector3(LAKE_CENTER.x, LAKE_PLANE_Y, LAKE_CENTER.y)
	add_child(visual)


## "The lake glows faintly from below (moonlight through water)" -- a large,
## very-low-energy OmniLight under the water plane. No DirectionalLight here
## (main.gd owns the moon).
func _add_lake_underglow() -> void:
	var light := OmniLight3D.new()
	light.name = "LakeUnderglow"
	light.light_color = COLOR_EMISSIVE
	light.light_energy = 0.15
	light.omni_range = 45.0
	light.position = Vector3(LAKE_CENTER.x, -1.5, LAKE_CENTER.y)
	add_child(light)


func _build_reeds() -> void:
	_add_reed_patch("ReedPatch1", REED_PATCH_1_X, REED_PATCH_1_Z, 3)
	_add_reed_patch("ReedPatch2", REED_PATCH_2_X, REED_PATCH_2_Z, 4)


## Wind-swayed reed patch (assets/shaders/wind_sway.gdshader via
## core/env/grass_field.gd), lighter/softer than the original dark stiff
## boxes (see the const block's polish-note comment above). Same footprint
## (REED_PATCH_SPREAD) and reed height as before so d09's "hides in the
## first patch" placement still reads correctly.
func _add_reed_patch(patch_name: String, center_x: float, center_z: float, rng_seed: int) -> void:
	var field := GrassField.new()
	field.name = patch_name
	field.base_color = REED_TINT_BASE
	field.tip_color = REED_TINT_TIP
	field.blade_height = REED_BLADE_HEIGHT
	field.blade_width = REED_BLADE_WIDTH
	field.sway_strength = 0.08 # reeds sway less than open grass -- taller, stiffer stems
	add_child(field)
	field.scatter(
		Vector3(center_x, 0.0, center_z),
		Vector2(REED_PATCH_SPREAD * 2.0, REED_PATCH_SPREAD * 2.0),
		REED_DENSITY, rng_seed
	)


## Places LILY_COUNT pads, each exactly LILY_STEP apart (center-to-center),
## alternating a gentle zigzag heading so the chain snakes without ever
## changing the actual edge-to-edge gap (LILY_STEP already bakes in
## 2*radius + the target gap, so the distance between any two consecutive
## pad CENTERS is correct by construction regardless of heading).
func _build_lily_chain() -> void:
	var pos: Vector3 = LILY_START
	for i: int in range(LILY_COUNT):
		var pad := LilyPad.new()
		pad.name = "LilyPad_%d" % i
		pad.radius = LILY_RADIUS
		pad.thickness = LILY_THICKNESS
		pad.amplitude = LILY_BOB_AMPLITUDE
		pad.period = LILY_BOB_PERIOD
		pad.phase_offset = float(i) * (TAU / float(LILY_COUNT))
		pad.position = pos
		add_child(pad)
		_lily_pads.append(pad)

		var angle_degrees: float = LILY_ZIGZAG_DEGREES if i % 2 == 0 else -LILY_ZIGZAG_DEGREES
		var angle_radians: float = deg_to_rad(angle_degrees)
		var direction: Vector3 = Vector3(cos(angle_radians), 0.0, sin(angle_radians))
		pos += direction * LILY_STEP


func _build_whale() -> void:
	_whale = WhaleDrift.new()
	_whale.name = "WhaleDrift"
	_whale.amplitude = WHALE_DRIFT_AMPLITUDE
	_whale.period = WHALE_DRIFT_PERIOD
	add_child(_whale)

	_tail_visual = _add_whale_mound("Tail", TAIL_CENTER, TAIL_RADIUS, COLOR_HIDE)
	_body_visual = _add_whale_mound("Body", BODY_CENTER, BODY_RADIUS, COLOR_HIDE)
	_head_visual = _add_whale_mound("Head", HEAD_CENTER, HEAD_RADIUS, COLOR_HIDE)

	_flipper_ledge_center = _add_whale_shelf(
		"FlipperLedge", FLIPPER_LEDGE_ANCHOR_X, FLIPPER_LEDGE_ANCHOR_Z,
		TAIL_CENTER, TAIL_RADIUS, FLIPPER_LEDGE_HEIGHT_ABOVE_ANCHOR, FLIPPER_LEDGE_SIZE, COLOR_SHORE
	)
	_belly_shelf_center = _add_whale_shelf(
		"BellyShelf", BELLY_SHELF_ANCHOR_X, BELLY_SHELF_ANCHOR_Z,
		BODY_CENTER, BODY_RADIUS, BELLY_SHELF_HEIGHT_ABOVE_ANCHOR, BELLY_SHELF_SIZE, COLOR_SHORE
	)
	_dorsal_crest_center = _add_whale_shelf(
		"DorsalCrest", BODY_CENTER.x, BODY_CENTER.z,
		BODY_CENTER, BODY_RADIUS, DORSAL_CREST_HEIGHT_ABOVE_ANCHOR, DORSAL_CREST_SIZE, COLOR_SHORE
	)

	var slide_bottom: Vector3 = _belly_shelf_center + Vector3(0.0, DORSAL_SLIDE_LANDING_CLEARANCE, 0.0)
	_add_whale_ramp("DorsalSlide", _dorsal_crest_center, slide_bottom, DORSAL_SLIDE_WIDTH, DORSAL_SLIDE_THICKNESS, COLOR_HIDE, DORSAL_SLIDE_FRICTION)

	_build_tail_seesaw()
	_build_blowhole()
	_build_water_spout()
	_build_whale_shell()


## ROADMAP M3 giant treatment: swaps wisp_whale_b.glb in as the whale's
## actual visible body via a plain ModelSlot (static mesh, no rig -- "animate
## by TRANSFORM", per the task brief; WhaleDrift already IS that transform).
## The GLB lands in its own small anchor (mirrors bramble's BearShellAnchor),
## parented under `_whale` so it rides the drift/dive exactly like every
## other shape on the compound body -- no separate sync code needed (same
## reasoning as the dorsal slide / tail seesaw's own nested-AnimatableBody3D
## comments elsewhere in this file). Only once the swap actually lands does
## this hide the old Tail/Body/Head sphere VISUALS (their collision, and
## every shelf/ledge/rim built on top of them, stays exactly as-is -- the
## brief's "keep its collision exactly"): if wisp_whale_b.glb is ever
## missing, the primitive mounds are what a player sees instead, same
## zero-GLBs-required floor every other ModelSlot in this game honors.
func _build_whale_shell() -> void:
	var anchor := Node3D.new()
	anchor.name = "WhaleShellAnchor"
	anchor.position = WHALE_SHELL_POSITION
	anchor.rotation_degrees.y = WHALE_SHELL_YAW_DEGREES

	var slot := ModelSlot.new()
	slot.name = "ModelSlot"
	slot.model_id = "wisp_whale_b"
	slot.target_height = WHALE_SHELL_TARGET_HEIGHT
	anchor.add_child(slot)

	_whale.add_child(anchor) # slot._ready() (the swap) fires synchronously here

	if slot.get_child_count() > 0:
		_tail_visual.visible = false
		_body_visual.visible = false
		_head_visual.visible = false


## Adds a MeshInstance3D + CollisionShape3D directly as children of `_whale`
## -- part of the SAME compound physics body, so it rides the whole-whale
## drift with the exact same velocity as every other shape on it. Returns
## the visual mesh so callers (the giant-treatment shell swap) can hide it
## later without a second lookup by name.
func _add_whale_mound(mound_name: String, center: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = mound_name
	visual.mesh = mesh
	visual.position = center
	_whale.add_child(visual)

	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	shape.shape = sphere_shape
	shape.position = center
	_whale.add_child(shape)

	return visual


## A flat platform anchored on a mound's surface (bramble's shelf pattern),
## added directly to `_whale`. Returns the platform's own center so callers
## (dreamling placement, the dorsal slide) can build on top of it exactly.
func _add_whale_shelf(shelf_name: String, anchor_x: float, anchor_z: float, center_ref: Vector3, radius_ref: float, height_above_anchor: float, size: Vector3, color: Color) -> Vector3:
	var anchor_y: float = _sphere_surface_y(center_ref, radius_ref, anchor_x, anchor_z)
	var shelf_center: Vector3 = Vector3(anchor_x, anchor_y + height_above_anchor, anchor_z)

	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = shelf_name
	visual.mesh = mesh
	visual.position = shelf_center
	_whale.add_child(visual)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = shelf_center
	_whale.add_child(shape)

	return shelf_center


## A long smooth ramp between two arbitrary 3D points, oriented via
## Basis.looking_at (not axis-aligned, unlike bramble's paw ramps, since the
## crest and the belly shelf don't share an axis). Needs its OWN nested
## AnimatableBody3D (not a shape directly on `_whale`): PhysicsMaterial
## friction is a per-BODY property in Godot, so giving the slide its low
## friction without making the WHOLE whale slippery means it must be a
## separate body. Nesting it under `_whale` still inherits the whale's
## drift correctly -- `sync_to_physics` diffs this body's own
## get_global_transform() each physics frame, which already composes in
## the parent's motion, exactly like worlds/bramble/breathing_chest.gd's
## single-body case, just one level deeper.
func _add_whale_ramp(ramp_name: String, top: Vector3, bottom: Vector3, width: float, thickness: float, color: Color, friction: float) -> void:
	var direction: Vector3 = bottom - top
	var length: float = direction.length()
	var mid: Vector3 = (top + bottom) * 0.5
	var ramp_basis: Basis = Basis.looking_at(direction.normalized(), Vector3.UP)

	var ramp_body := AnimatableBody3D.new()
	ramp_body.name = ramp_name + "Body"
	ramp_body.sync_to_physics = true
	ramp_body.collision_layer = 1
	ramp_body.collision_mask = 0
	var physics_mat := PhysicsMaterial.new()
	physics_mat.friction = friction
	ramp_body.physics_material_override = physics_mat
	ramp_body.transform = Transform3D(ramp_basis, mid)
	_whale.add_child(ramp_body)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, thickness, length)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = mesh
	ramp_body.add_child(visual)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = mesh.size
	shape.shape = box_shape
	ramp_body.add_child(shape)


## The fluke -- its own nested AnimatableBody3D (same reasoning as the
## ramp: it has local motion of its own, rotation this time, which needs
## its own sync_to_physics body regardless of the friction question).
## The tail_bridge-equivalent traversal element here is TailSeesaw (Wisp has
## no marmalade-style TailBridge/arc_position() -- confirmed by repo search;
## this world's own bonus tail element is the rocking seesaw plank per
## worlds/wisp/tail_seesaw.gd). Giant-treatment pass: collision/shape/
## position all stay exactly as authored (still nested under `_whale`, still
## rides the drift/dive identically) -- only re-skinned to a cream tone
## pulled from wisp_whale_b's own belly color so it reads as part of the new
## whale instead of the old silver-hide primitive palette.
const TAIL_SEESAW_COLOR: Color = Color("F0EAD9") # cream, matches the GLB's belly


func _build_tail_seesaw() -> void:
	var seesaw := TailSeesaw.new()
	seesaw.name = "TailSeesaw"
	seesaw.length = TAIL_SEESAW_LENGTH
	seesaw.plank_color = TAIL_SEESAW_COLOR
	seesaw.position = TAIL_SEESAW_PIVOT
	_whale.add_child(seesaw)


## The blowhole: a rim bump (mirrors bramble's ear bump) directly on
## `_whale`'s compound body, plus the DreamDoor itself parented under
## `_whale` so it moves with the head.
func _build_blowhole() -> void:
	var anchor_y: float = _sphere_surface_y(HEAD_CENTER, HEAD_RADIUS, BLOWHOLE_ANCHOR_X, BLOWHOLE_ANCHOR_Z)
	var bump_center: Vector3 = Vector3(BLOWHOLE_ANCHOR_X, anchor_y + BLOWHOLE_BUMP_HEIGHT, BLOWHOLE_ANCHOR_Z)

	var mesh := SphereMesh.new()
	mesh.radius = BLOWHOLE_BUMP_RADIUS
	mesh.height = BLOWHOLE_BUMP_RADIUS * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_SHORE
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "BlowholeRim"
	visual.mesh = mesh
	visual.position = bump_center
	_whale.add_child(visual)

	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = BLOWHOLE_BUMP_RADIUS
	shape.shape = sphere_shape
	shape.position = bump_center
	_whale.add_child(shape)

	var door: DreamDoor = DREAM_DOOR_SCENE.instantiate() as DreamDoor
	door.name = "DreamDoor"
	door.position = bump_center
	_whale.add_child(door)


## A plain Area3D -- rides `_whale`'s drift automatically the moment it's
## parented under it, no sync flag needed (Area3D overlap checks always use
## the node's current global transform, which already composes the
## parent's motion).
func _build_water_spout() -> void:
	var base_y: float = _sphere_surface_y(HEAD_CENTER, HEAD_RADIUS, WATER_SPOUT_ANCHOR_X, WATER_SPOUT_ANCHOR_Z)
	_water_spout = WaterSpout.new()
	_water_spout.name = "WaterSpout"
	_water_spout.height = WATER_SPOUT_HEIGHT
	_water_spout.position = Vector3(WATER_SPOUT_ANCHOR_X, base_y, WATER_SPOUT_ANCHOR_Z)
	_whale.add_child(_water_spout)


## d04/d05/d07/d08/d10 are physically ON the whale, so they're parented
## under `_whale` (or the specific moving prop on it) to ride the drift --
## `check_placements.gd` will report these as moving_platform (parent !=
## world root) and skip the ground-raycast for them, per its own contract;
## their rest positions are validated by the anchor math above instead
## (see docs/verify/world-wisp-VERIFY.md). d02/d03 sit near (not riding)
## specific lily pads -- static world children, still correctly checked by
## the raycast since a pad's XZ never changes, only its Y bobs +/-0.2 m.
func _build_dreamlings() -> void:
	_add_dreamling("d01", Vector3(-65.0, 0.55, -8.0), self)
	_add_dreamling("d02", _lily_pads[0].position + Vector3(0.0, 0.5, 0.0), self)
	_add_dreamling("d03", _lily_pads[4].position + Vector3(0.0, 0.5, 0.0), self)
	_add_dreamling("d04", _flipper_ledge_center + Vector3(0.0, 0.5, 0.0), _whale)
	_add_dreamling("d05", _belly_shelf_center + Vector3(0.0, 0.5, 0.0), _whale)
	_add_dreamling("d08", _dorsal_crest_center + Vector3(0.0, 0.6, 0.0), _whale)
	_add_dreamling("d09", Vector3(REED_PATCH_1_X, 0.9, REED_PATCH_1_Z + 1.2), self)

	# Clears the blowhole rim bump the same way bramble's d10 clears the ear
	# bump: offset far enough from the anchor that the bump's own radius
	# plus dreamling clearance can't embed it (bump_radius 1.6 + clearance
	# 0.35 = 1.95 m required; the 2.3 m offset used here matches bramble's
	# own margin exactly).
	var d10_z: float = BLOWHOLE_ANCHOR_Z - 2.3
	var d10_y: float = _sphere_surface_y(HEAD_CENTER, HEAD_RADIUS, BLOWHOLE_ANCHOR_X, d10_z) + BLOWHOLE_BUMP_HEIGHT
	_add_dreamling("d10", Vector3(BLOWHOLE_ANCHOR_X, d10_y, d10_z), _whale)

	# d06 rides a bobbing lily pad (parented, local offset above its top).
	_add_dreamling("d06", Vector3(0.0, LILY_THICKNESS * 0.5 + 0.35, 0.0), _lily_pads[7])

	# d07 rides the spout column (parented, near the top of its 14 m rise).
	_add_dreamling("d07", Vector3(0.0, WATER_SPOUT_HEIGHT - 1.0, 0.0), _water_spout)


func _build_camera_hints() -> void:
	# Yaw convention (bramble.gd, confirmed against core/camera/camera_hint.gd):
	# 0 deg = default -Z forward; -90 deg = +X; +90 deg = -X.
	_add_camera_hint("ShoreApproachHint", Vector3(-60.0, 8.0, 0.0), Vector3(60.0, 20.0, 60.0), -90.0, 0, 1.0)
	_add_camera_hint("LakeCrossingHint", Vector3(-21.0, 10.0, 0.0), Vector3(70.0, 24.0, 44.0), -90.0, 1, 0.8)
	_add_camera_hint("SpineRunHint", Vector3(50.0, 16.0, 0.0), Vector3(70.0, 28.0, 50.0), 90.0, 2, 0.8)


func _add_camera_hint(hint_name: String, center: Vector3, size: Vector3, yaw_degrees: float, priority: int, blend_time: float) -> void:
	var hint := CameraHint.new()
	hint.name = hint_name
	hint.priority = priority
	hint.yaw_degrees = yaw_degrees
	hint.blend_time = blend_time

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	hint.add_child(shape)
	add_child(hint)


# --- Dreamkeepers (Dressing M2) ---------------------------------------------

## Direct per-world spawn call (not a WorldBase._wire_* hook): this pass's
## territory excludes editing worlds/common/world_base.gd. Data-driven from
## data/dreamkeepers/wisp.json (schema: id, rig, pos, face_yaw).
func _build_dreamkeepers() -> void:
	var path: String = DREAMKEEPER_DATA_PATH_FORMAT % world_id()
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_warning("Wisp: dreamkeeper data at %s did not parse to a Dictionary" % path)
		return
	var list: Variant = (parsed as Dictionary).get("dreamkeepers", [])
	if not (list is Array):
		return
	for entry: Variant in (list as Array):
		if entry is Dictionary:
			_spawn_dreamkeeper(entry as Dictionary)


func _spawn_dreamkeeper(entry: Dictionary) -> void:
	var pos_raw: Variant = entry.get("pos", [])
	if not (pos_raw is Array) or (pos_raw as Array).size() < 3:
		push_warning("Wisp: dreamkeeper entry '%s' has no valid 'pos' -- skipped" % String(entry.get("id", "?")))
		return
	var pos_arr: Array = pos_raw as Array
	var keeper: Dreamkeeper = DREAMKEEPER_SCENE.instantiate() as Dreamkeeper
	keeper.name = "Dreamkeeper_%s" % String(entry.get("id", "keeper"))
	# Set BEFORE add_child -- see dreamkeeper.gd's own header / pillow_fort.
	# gd's identical comment / critter.gd's kind/world_id precedent.
	keeper.keeper_id = String(entry.get("id", ""))
	keeper.rig_id = String(entry.get("rig", ""))
	keeper.face_yaw_degrees = float(entry.get("face_yaw", 0.0))
	keeper.position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
	add_child(keeper)


# --- Dressing M2 props -------------------------------------------------------

func _build_dressing() -> void:
	for i: int in STONE_SOFT_POSITIONS.size():
		_add_dressing_prop("StoneSoft%d" % i, "stone_soft", STONE_SOFT_HEIGHT, STONE_SOFT_POSITIONS[i],
			_dressing_sphere(STONE_SOFT_HEIGHT * 0.5, COLOR_SHORE))
		_add_prop_cylinder_collision(STONE_SOFT_POSITIONS[i], STONE_SOFT_COLLISION_RADIUS, STONE_SOFT_HEIGHT)

	_add_dressing_prop("StumpDoorVisual", "stump_door", STUMP_DOOR_HEIGHT, STUMP_DOOR_POSITION,
		_dressing_box(Vector3(0.5, STUMP_DOOR_HEIGHT, 0.3), Color("8A6552")))
	_add_prop_cylinder_collision(STUMP_DOOR_POSITION, STUMP_DOOR_COLLISION_RADIUS, STUMP_DOOR_HEIGHT)

	for i: int in CLOVER_TUFT_POSITIONS.size():
		_add_dressing_prop("CloverTuft%d" % i, "clover_tuft", CLOVER_TUFT_HEIGHT, CLOVER_TUFT_POSITIONS[i],
			_dressing_sphere(0.15, Color("6E8F6A")))

	for i: int in MOON_DAISY_POSITIONS.size():
		_add_dressing_prop("MoonDaisy%d" % i, "moon_daisy", MOON_DAISY_HEIGHT, MOON_DAISY_POSITIONS[i],
			_dressing_sphere(0.12, Color("F5F2E8")))

	for i: int in SEED_PUFF_POSITIONS.size():
		_add_dressing_prop("SeedPuff%d" % i, "seed_puff", SEED_PUFF_HEIGHT, SEED_PUFF_POSITIONS[i],
			_dressing_sphere(0.14, Color("E8E4D8")))


func _dressing_box(size: Vector3, color: Color) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	return mesh


func _dressing_sphere(radius: float, color: Color) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	return mesh


## Ground-anchored container (D10 pattern, matching every other prop in this
## file): `anchor` + the primitive mesh are the only two children until a
## ModelSlot swap hides the primitive.
func _add_dressing_prop(anchor_name: String, model_id: String, target_height: float, prop_position: Vector3, primitive_mesh: Mesh) -> void:
	var anchor := Node3D.new()
	anchor.name = anchor_name
	anchor.position = prop_position
	add_child(anchor)

	var visual := MeshInstance3D.new()
	visual.name = "Primitive"
	visual.mesh = primitive_mesh
	visual.position = Vector3(0.0, target_height * 0.5, 0.0)
	anchor.add_child(visual)

	var slot := ModelSlot.new()
	slot.name = "ModelSlot"
	slot.model_id = model_id
	slot.target_height = target_height
	anchor.add_child(slot)


## Simple static cylinder collider (brief: "only stump_door + stone_soft +
## soft_pine get simple static collision cylinders" -- everything else in
## this pass stays walk-through, generosity floor).
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
	add_child(body)


# --- ROADMAP M3 THE DIVE (docs/design/world-cards/wisp.md's signature body-
# function) -------------------------------------------------------------

## setup() BEFORE add_child() -- entering the tree fires _ready() SYNCHRO-
## NOUSLY (bramble.gd's own _build_rollover() comment, same engine behavior
## here), so a reversed order would run DiveSequence._ready() with _world/
## _whale/_lake_surface still unset. LakeSurface is looked up by name (built
## by _build_lake() -> _add_lake_plane(), which runs before this in _ready()).
func _build_dive() -> void:
	var dive := DiveSequence.new()
	dive.name = "DiveSequence"
	dive.setup(self, _whale, get_node("LakeSurface") as MeshInstance3D)
	add_child(dive)


# --- Layout-iteration tool (mirrors worlds/bramble/bramble.gd's own
# _build_dev_camera() verbatim): a static free camera for framing stills
# while placing the whale shell / dive geometry blind (no editor, headless-
# or-windowed CLI only). Inert unless --devcam is passed; never affects
# normal play. Reads --devcam_pos=x,y,z / --devcam_look=x,y,z (comma floats)
# so a still can be re-aimed per capture without a code edit each time.
func _build_dev_camera() -> void:
	var devcam_flag: Variant = Harness.flag("devcam", false)
	if devcam_flag == false or devcam_flag == null:
		return
	var cam := Camera3D.new()
	cam.name = "DevCam"
	add_child(cam)
	cam.position = _parse_vec3(str(Harness.flag("devcam_pos", "")), Vector3(40.0, 45.0, 110.0))
	cam.look_at(_parse_vec3(str(Harness.flag("devcam_look", "")), Vector3(40.0, 8.0, 0.0)), Vector3.UP)
	cam.fov = float(str(Harness.flag("devcam_fov", "60")))
	cam.current = true
	print("DEVCAM %s" % JSON.stringify({"pos": [cam.position.x, cam.position.y, cam.position.z]}))


func _parse_vec3(s: String, fallback: Vector3) -> Vector3:
	var parts: PackedStringArray = s.split(",")
	if parts.size() < 3:
		return fallback
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
