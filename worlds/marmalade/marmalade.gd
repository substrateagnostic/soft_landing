class_name Marmalade
extends WorldBase
## Marmalade — world 2 (docs/design/world-cards/marmalade.md): an enormous
## marmalade cat asleep across a tiny hillside village, dreaming of warm
## windowsills. Layout along +X from the village-square spawn: village
## lane (10 houses) -> two purr-thermal chimneys -> rooftop hop chain
## (cluster A) -> the tail bridge (signature moving platform, sweeps
## between cluster A and cluster B) OR the flank steps (patient parallel
## route, same span) -> rooftop cluster B -> a ridge shelf where both
## routes converge -> the back-ridge mound -> the head mound -> twin ear
## peaks with the DreamDoor nested between them. Ten dreamlings placed per
## the card's d01-d10 route (see VERIFY doc for the full table). Grey-box:
## primitive meshes, flat StandardMaterial3D colors from the card only —
## except the giant herself (_build_cat_giant(), M3) and her dressing/nook
## props, which use the real generated Meshy assets via ModelSlot.
##
## M3 (ROADMAP.md, docs/verify/marmalade-giant-VERIFY.md): the cat is now a
## real curled-plush GLB (assets/models/meshy/generated/marmalade_cat.glb)
## at village-dwarfing scale, with a soft collision blocker and a subtle
## ambient breathing sine (see _process() below). At 10/10 dreamlings (or
## the --stretch dev flag), worlds/marmalade/stretch_sequence.gd plays THE
## STRETCH: she rises, arches, holds, and resettles while four rooftop
## plates (RoofB0-3) permanently relocate into a new "chimney-hop" chain
## opening a hidden attic-balcony nook.

const DREAMLING_SCENE: PackedScene = preload("res://worlds/common/dreamling.tscn")
const DREAM_DOOR_SCENE: PackedScene = preload("res://worlds/common/dream_door.tscn")

# --- Palette (world-cards/marmalade.md) -----------------------------------
const COLOR_CAT: Color = Color("D98E4A") # marmalade orange (cat)
const COLOR_CAT_DARK: Color = Color("A6672F") # darker marmalade — ears, flank steps, chimney accents
const COLOR_ROOF: Color = Color("B4654A") # terracotta (roofs, rooftop chain)
const COLOR_ROOF_DARK: Color = Color("934F3C") # darker terracotta — chimney stacks
const COLOR_WALL: Color = Color("EFE6D8") # cream plaster
const COLOR_WINDOW: Color = Color("F2C879") # honey (windows, lanterns — emissive)
const COLOR_HILL: Color = Color("7C9082") # dusk sage (the hill)
const COLOR_MOAT: Color = Color(0.404, 0.463, 0.420) # darker sage, the boundary dip (bramble-moat pattern)
# ROUND 2 (director's note 2, "flat single-color ground"): sage <-> warm
# grey, echoing the terracotta roofs without competing with them.
const GROUND_TINT_B: Color = Color("8C8478")

# --- Ground / moat (bramble-moat pattern: void ring sits below rescue line) -
const GROUND_SIZE: Vector2 = Vector2(170.0, 90.0) # X: -85..85, Z: -45..45
const MOAT_SIZE: Vector2 = Vector2(220.0, 140.0)
const MOAT_TOP_Y: float = -9.0
const MOAT_THICKNESS: float = 1.0
const GROUND_THICKNESS: float = 1.0
const RESCUE_FLOOR_Y: float = -8.0 # card: "below the village foundations (-8)"

# --- Spawns (village square, arriving from the fort direction, facing +X) --
const SPAWN_PIP: Vector3 = Vector3(-65.0, 0.5, 0.0)
const SPAWN_OTTO: Vector3 = Vector3(-67.0, 0.5, 2.0)

# --- Village houses (10, box + prism roof, honey window quad) --------------
const HOUSE_WALL_SIZE: Vector3 = Vector3(2.2, 1.6, 2.2)
const HOUSE_ROOF_HEIGHT: float = 1.0
const HOUSE_ROOF_OVERHANG: float = 0.4
const WINDOW_SIZE: Vector3 = Vector3(0.6, 0.6, 0.06)
const WINDOW_Y: float = 0.85
const CHIMNEY_SIZE: Vector3 = Vector3(0.3, 0.8, 0.3)
const AWNING_SIZE: Vector3 = Vector3(1.3, 0.15, 1.0)
const AWNING_Y: float = 0.9
const DREAMLING_CLEARANCE: float = 0.3 # matches bramble's convention (chest/haunch dreamlings)

# House layout: [x, z, has_chimney, has_awning]. z<0 houses face +Z (window/
# awning toward the lane center); z>0 houses face -Z. 10 houses total.
const HOUSE_LAYOUT: Array = [
	[-62.0, -8.0, false, false],
	[-62.0, 9.0, false, false],
	[-56.0, -14.0, false, true], # d02's low awning — the first jump
	[-56.0, 13.0, false, false],
	[-50.0, -9.0, false, false],
	[-50.0, 10.0, false, false],
	[-44.0, -13.0, true, false], # d04's chimney top
	[-44.0, 12.0, false, false],
	[-38.0, -7.0, false, false],
	[-38.0, 8.0, false, false],
]

# --- Purr thermals (2, chimneys puffing 6 m updrafts on the purr cycle) ----
const THERMAL_HEIGHT: float = 6.0
const THERMAL_RADIUS: float = 1.1
const THERMAL_A_POS: Vector3 = Vector3(-30.0, 0.0, -6.0)
const THERMAL_B_POS: Vector3 = Vector3(-30.0, 0.0, 9.0)
const THERMAL_B_PHASE: float = 3.5

# --- Rooftop hop chain (flat-topped terracotta roofs, gaps 1.2-2.0 m) ------
const ROOF_SIZE: Vector2 = Vector2(2.4, 2.4)
const ROOF_THICKNESS: float = 0.4

# Cluster A: village lane -> the tail-bridge / flank-steps gap.
const CLUSTER_A: Array[Vector3] = [
	Vector3(-24.0, 2.0, -3.0),
	Vector3(-20.3, 2.7, 1.5),
	Vector3(-16.4, 3.4, -2.5), # d03 — mid rooftop chain
	Vector3(-12.3, 4.1, 2.0),
	Vector3(-8.0, 4.8, -2.5), # last of cluster A — the tail-bridge/flank-steps departure point
]

# Cluster B: the far side of the gap -> the ridge shelf.
const CLUSTER_B: Array[Vector3] = [
	Vector3(2.0, 5.6, -2.5), # first of cluster B — the tail-bridge/flank-steps arrival point
	Vector3(5.8, 6.4, 2.0),
	Vector3(9.9, 7.2, -1.5),
	Vector3(14.0, 8.0, 1.5),
]

# --- The tail bridge (signature gift): sweeps cluster A <-> cluster B ------
const TAIL_PIVOT: Vector3 = Vector3(-3.0, 5.3, -14.0)
const TAIL_ARM_LENGTH: float = 11.8
const TAIL_YAW_RANGE_DEGREES: float = 25.0
const TAIL_PERIOD: float = 8.0
const TAIL_FOOTPRINT: Vector2 = Vector2(2.6, 2.0)
const TAIL_THICKNESS: float = 0.5

# --- Flank steps (the cat's folded paws — patient, no-timing alternative) --
const FLANK_STEP_SIZE: Vector3 = Vector3(3.0, 1.0, 3.0)
const FLANK_STEPS: Array[Vector3] = [
	Vector3(-8.0, 5.0, 7.0),
	Vector3(-4.0, 6.0, 7.0),
	Vector3(0.0, 7.0, 7.0), # d05 — open, on the paw steps
	Vector3(5.0, 8.0, 7.0),
	Vector3(10.0, 9.0, 7.0),
]

# --- Ridge shelf (d08 convergence — tail-bridge OR flank-steps route) ------
const SHELF_POSITION: Vector3 = Vector3(18.0, 9.6, 3.0)
const SHELF_SIZE: Vector3 = Vector3(3.0, 0.6, 3.0)

# --- Back ridge (the cat's spine) ------------------------------------------
const RIDGE_CENTER: Vector3 = Vector3(26.0, -3.0, 0.0)
const RIDGE_RADIUS: float = 14.0 # top height = -3 + 14 = 11.0

# --- The giant herself (M3, ROADMAP.md "Marmalade gets the giant treatment"):
# assets/models/meshy/generated/marmalade_cat.glb (curled sleeping plush
# tabby, generated+refined — tools/meshy/forge_report.json id="marmalade_cat",
# status "ok") via plain ModelSlot (quadruped — Meshy can't rig; static
# sculpt + the procedural THE STRETCH keystone, worlds/marmalade/
# stretch_sequence.gd). Placement reuses the exact XZ/footprint the old
# visual-only CatSilhouette bulk it replaces already proved out by hand
# (world-marmalade-VERIFY.md (e)): the camera rig's pitch is reactive only
# (biases down near gaps, base -32 deg) with no per-world hint, so the
# nearest WALKABLE cat geometry (the ridge, starting x=12) is too far/low to
# register in the spawn establishing shot — this bulk sits in the gap between
# the village (ends x=-38) and the purr thermals (x=-30) / rooftop chain
# (starts x=-24), footprint x=-43..-25, checked clear (>0.3 m margin) of
# every thermal/roof/step/shelf position. CAT_GIANT_CENTER anchors the
# ModelSlot at ground level (she rests on the hill); CAT_COLLISION_CENTER/
# RADIUS is the exact old silhouette sphere (same already-proven-clear
# geometry), now real collision instead of none — "soft collision blocker so
# players can't walk inside her," generous/not mesh-hugging per this
# codebase's established convention (bramble.gd's torso-capsule blocker).
const CAT_GIANT_CENTER: Vector3 = Vector3(-34.0, 0.0, 0.0)
const CAT_GIANT_TARGET_HEIGHT: float = 18.0 # village-dwarfing: ~7x the ~2.6m house peak
# CAT_COLLISION_* deliberately does NOT reuse the old SILHOUETTE_CENTER/RADIUS
# (-34,6,0) r9 verbatim — that sphere was hand-verified clear of every prop's
# BASE position only (never collidable itself), but d07 (worlds/common/
# dreamling.gd) rides the purr thermal's TOP (world ~(-30,5.6,-6) — see
## marmalade.gd's own _build_dreamlings()), much closer to this sphere's own
# height than the thermal's base is. Caught live by
# tools/props/check_placements.gd (d07 FAILED, inside_solid:true, at r9);
# re-centered/shrunk to clear d07 (3.7m), both purr-thermal columns
# (>2.1m), and the nearest village houses (>0.9m) — verified by hand,
# 3D point-to-nearest-surface distance for each.
const CAT_COLLISION_CENTER: Vector3 = Vector3(-37.0, 5.0, 0.0)
const CAT_COLLISION_RADIUS: float = 5.5
const CAT_BREATH_AMPLITUDE: float = 0.015 # +/-1.5% y-scale — subtle, ambient, always-on
const CAT_BREATH_PERIOD: float = 6.0

# --- Rooftop garden (d09 — hidden behind tall pots) -------------------------
const GARDEN_ANCHOR_X: float = 22.0
const GARDEN_ANCHOR_Z: float = -4.0
const GARDEN_POT_COUNT: int = 4
const GARDEN_POT_RADIUS: float = 0.35
const GARDEN_POT_HEIGHT: float = 1.0
const GARDEN_POT_SPREAD: float = 0.7

# --- Head + twin ear peaks (the summit, DreamDoor between them) ------------
const HEAD_CENTER: Vector3 = Vector3(48.0, -4.0, 0.0)
const HEAD_RADIUS: float = 16.0 # top height = -4 + 16 = 12.0
const EAR_ANCHOR_X: float = 52.0
const EAR_LEFT_Z: float = -3.0
const EAR_RIGHT_Z: float = 3.0
const EAR_BUMP_HEIGHT: float = 2.0
const EAR_BUMP_RADIUS: float = 1.6
const EAR_DOOR_LIFT: float = 0.5
const D10_ANCHOR_X: float = 50.0
const D10_ANCHOR_Z: float = -1.5

# --- Dressing M2 props (assets/models/meshy/generated/, tools/meshy/
# manifest.json target_height_hint values). Lane props sit on the village
# lane centerline (z=0) between consecutive HOUSE_LAYOUT x columns rather
# than on any house footprint; the picnic basket and berry-bush pairs sit
# off the spawn's direct forward line; the two rooftop moths perch on
# houses with neither a chimney nor an awning (HOUSE_LAYOUT indices 0 and
# 9) so they never compete with d02/d04's existing placements. No collision
# on anything here (none of mushroom_lamp/berry_bush/picnic_basket/
# moth_small are in the brief's stump_door/stone_soft/soft_pine collision
# list) -- generosity floor, and it means nothing here can physically block
# tools/harness/scripts/finale_marmalade.json's walk-in route. -------------
const MUSHROOM_LAMP_HEIGHT: float = 0.5
const MUSHROOM_LAMP_POSITIONS: Array[Vector3] = [
	Vector3(-59.0, 0.0, 0.0),
	Vector3(-53.0, 0.0, 0.0),
	Vector3(-47.0, 0.0, 0.0),
	Vector3(-41.0, 0.0, 0.0),
]
const BERRY_BUSH_HEIGHT: float = 0.9
const BERRY_BUSH_POSITIONS: Array[Vector3] = [
	Vector3(-64.0, 0.0, -6.0),
	Vector3(-64.0, 0.0, 7.0),
	Vector3(-39.0, 0.0, -6.0),
	Vector3(-39.0, 0.0, 7.0),
]
const PICNIC_BASKET_HEIGHT: float = 0.4
const PICNIC_BASKET_POSITION: Vector3 = Vector3(-63.0, 0.0, -3.5) # the village square, off the spawn's direct +X line
const MOTH_SMALL_HEIGHT: float = 0.25
## Which HOUSE_LAYOUT entries get a rooftop moth (indices, not positions --
## both chosen for no chimney/awning so the perch never overlaps d02/d04).
const MOTH_SMALL_HOUSE_INDICES: Array[int] = [0, 9]

var _tail_bridge: TailBridge = null
var _thermal_a: PurrThermal = null
var _d02_position: Vector3 = Vector3.ZERO
var _d04_position: Vector3 = Vector3.ZERO
var _cat_anchor: Node3D = null
var _stretch: StretchSequence = null
var _cat_breath_time: float = 0.0


func _ready() -> void:
	_build_ground()
	_build_cat_giant()
	_build_village()
	_build_purr_thermals()
	_build_rooftop_chain()
	_build_tail_bridge()
	_build_flank_steps()
	_build_ridge_shelf()
	_build_ridge()
	_build_garden()
	_build_head_and_ears()
	_build_dreamlings()
	_build_camera_hints()
	_build_home_door()
	_build_dressing()
	_build_stretch() # after the rooftop chain + cat giant: the sequence looks both up
	super._ready()


## THE STRETCH's ambient counterpart: a tiny, always-on y-scale breathing
## sine on CAT_GIANT_CENTER, matching worlds/bramble/breathing_chest.gd's
## `_rest + sin(_time * TAU / period) * amplitude` convention. Suppressed
## while StretchSequence itself is animating the SAME anchor's scale
## (`_stretch.playing`) so the two animations never fight over one property
## — resumed automatically once the sequence resettles her to Vector3.ONE.
func _process(delta: float) -> void:
	if _cat_anchor == null:
		return
	if _stretch != null and _stretch.playing:
		return
	_cat_breath_time += delta
	var s: float = 1.0 + sin(_cat_breath_time * TAU / CAT_BREATH_PERIOD) * CAT_BREATH_AMPLITUDE
	_cat_anchor.scale = Vector3(1.0, s, 1.0)


func world_id() -> String:
	return "marmalade"


func spawn_points() -> Dictionary:
	var facing_cat: Basis = Basis.looking_at(Vector3.RIGHT, Vector3.UP) # +X, toward the cat
	return {
		"pip": Transform3D(facing_cat, SPAWN_PIP),
		"otto": Transform3D(facing_cat, SPAWN_OTTO),
	}


func objective_ids() -> Array[String]:
	return ["d01", "d02", "d03", "d04", "d05", "d06", "d07", "d08", "d09", "d10"] as Array[String]


func rescue_floor_y() -> float:
	return RESCUE_FLOOR_Y


## The way home: a doorframe at the village edge behind spawn, facing the
## cat, so leaving is always one interact away (worlds are never gated).
func _build_home_door() -> void:
	var door := WorldDoor.new()
	door.name = "HomeDoor"
	door.target_world = "pillow_fort"
	door.position = Vector3(SPAWN_PIP.x - 6.0, 0.0, 1.0)
	door.rotation_degrees = Vector3(0.0, 90.0, 0.0) # opening faces the cat (+X)
	door.exit_requested.connect(func() -> void:
		exit_requested_to.emit("pillow_fort")
		exit_requested.emit()
	)
	add_child(door)


# --- Geometry helpers -------------------------------------------------------

## Height of a sphere mound's surface directly above world (x, z); 0 if that
## point is outside the sphere's footprint. Used to anchor props exactly on
## a mound's surface instead of hand-guessing elevations (bramble pattern).
func _sphere_surface_y(center: Vector3, radius: float, x: float, z: float) -> float:
	var dx: float = x - center.x
	var dz: float = z - center.z
	var under_sqrt: float = radius * radius - dx * dx - dz * dz
	if under_sqrt < 0.0:
		return center.y
	return center.y + sqrt(under_sqrt)


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


func _add_mound(mound_name: String, center: Vector3, radius: float, color: Color) -> void:
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
	add_child(visual)

	var body := StaticBody3D.new()
	body.name = mound_name + "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	shape.shape = sphere_shape
	shape.position = center
	body.add_child(shape)
	add_child(body)


## Generic flat platform (roofs, flank steps, shelf) — box visual + box
## collision (never a trimesh: check_placements.gd's point-query caveat only
## applies to concave shapes, and every marmalade platform is a plain box).
func _add_box_platform(platform_name: String, center: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = platform_name
	visual.mesh = mesh
	visual.position = center
	add_child(visual)

	var body := StaticBody3D.new()
	body.name = platform_name + "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = center
	body.add_child(shape)
	add_child(body)


func _build_ground() -> void:
	_add_ground_slab("Moat", MOAT_SIZE, MOAT_TOP_Y, MOAT_THICKNESS, COLOR_MOAT)
	# D27 terrain v1 (bramble's template): the village hill rolls gently.
	# Every house from HOUSE_LAYOUT pins its own flat disc (a floating gap
	# under a wall reads broken; the discs keep foundations true), plus the
	# spawn/HomeDoor clearing. Patch sits at origin so local == world XZ.
	var ground := TerrainPatch.new()
	ground.name = "VillageGround"
	var flat_discs: Array[Vector3] = [
		Vector3(SPAWN_PIP.x, SPAWN_PIP.z, 8.0), # spawns + HomeDoor
	]
	for house: Array in HOUSE_LAYOUT:
		flat_discs.append(Vector3(float(house[0]), float(house[1]), 3.0))
	ground.setup(GROUND_SIZE, 0.4, 16.0, 3, flat_discs)
	add_child(ground)
	# ROUND 2 (director's note 2): patchy sage/warm-grey shader on the main
	# walkable ground (the moat stays flat -- boundary void ring, not
	# gameplay ground).
	(get_node("VillageGround") as MeshInstance3D).set_surface_override_material(0, _ground_patch_material(COLOR_HILL, GROUND_TINT_B))


## D22 graphics-v2 ROUND 2, assets/shaders/ground_patches.gdshader (director's
## note 2): builds a ShaderMaterial pre-loaded with a world's near-neighbor
## tint pair.
func _ground_patch_material(tint_a: Color, tint_b: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ground_patches.gdshader") as Shader
	mat.set_shader_parameter("tint_a", tint_a)
	mat.set_shader_parameter("tint_b", tint_b)
	return mat


## M3: the real giant, via ModelSlot (D10 seam — assets/models/meshy/
## generated/marmalade_cat.glb). Same grey-box-fallback contract as every
## other ModelSlot prop in this file (_add_dressing_prop): a small "Primitive"
## MeshInstance3D sibling under CatGiantAnchor keeps the exact old silhouette
## sphere shape/color as the fallback if the GLB is ever missing, so the game
## still works with zero GLBs on disk. D22 graphics-v2 lesson (see the const
## block's doc comment): cast_shadow OFF on BOTH the primitive and — once it
## swaps in synchronously inside this same function (ModelSlot._ready() fires
## when add_child() attaches it to an already-in-tree anchor, matching this
## file's established TailBridge-vs-thermal ordering note) — every
## GeometryInstance3D under the real GLB too, so this huge, close-to-the-
## village prop can never blanket the lamplit lane in real shadow.
func _build_cat_giant() -> void:
	var anchor := Node3D.new()
	anchor.name = "CatGiantAnchor"
	anchor.position = CAT_GIANT_CENTER
	add_child(anchor)
	_cat_anchor = anchor

	var mesh := SphereMesh.new()
	mesh.radius = CAT_GIANT_TARGET_HEIGHT * 0.5
	mesh.height = CAT_GIANT_TARGET_HEIGHT
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_CAT
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "Primitive"
	visual.mesh = mesh
	visual.position = Vector3(0.0, CAT_GIANT_TARGET_HEIGHT * 0.5, 0.0)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchor.add_child(visual)

	var slot := ModelSlot.new()
	slot.name = "ModelSlot"
	slot.model_id = "marmalade_cat"
	slot.target_height = CAT_GIANT_TARGET_HEIGHT
	anchor.add_child(slot)
	if slot.get_child_count() > 0:
		_disable_shadows_recursive(slot.get_child(0))

	_build_cat_collision_blocker()


func _disable_shadows_recursive(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_disable_shadows_recursive(child)


## "Soft collision blocker so players can't walk inside her" — generous,
## not mesh-hugging (this codebase's established convention for every giant
## blocker: bramble.gd's torso-capsule+head-sphere stack is the precedent).
## Reuses the exact old CatSilhouette sphere geometry (already hand-verified
## clear of every thermal/roof/step/shelf position, world-marmalade-VERIFY.md
## (e)) rather than re-deriving new clearance math for the real asset's
## (visually somewhat larger) curled silhouette.
func _build_cat_collision_blocker() -> void:
	var body := StaticBody3D.new()
	body.name = "CatGiantCollisionBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = CAT_COLLISION_RADIUS
	shape.shape = sphere_shape
	shape.position = CAT_COLLISION_CENTER
	body.add_child(shape)
	add_child(body)


## THE STRETCH (M3 keystone, worlds/marmalade/stretch_sequence.gd) — after
## the rooftop chain (needs RoofB0-3) and the cat giant (needs CatGiantAnchor)
## both already exist. setup() BEFORE add_child() — established ordering rule
## in this codebase (see bramble.gd's own _build_rollover() comment: entering
## the tree fires _ready() synchronously, so a reversed order runs _ready()
## before the world/anchor refs land).
func _build_stretch() -> void:
	_stretch = StretchSequence.new()
	_stretch.name = "StretchSequence"
	_stretch.setup(self, _cat_anchor)
	add_child(_stretch)


# --- Village -----------------------------------------------------------------

func _build_village() -> void:
	for entry: Array in HOUSE_LAYOUT:
		var pos: Vector2 = Vector2(entry[0], entry[1])
		var has_chimney: bool = entry[2]
		var has_awning: bool = entry[3]
		_add_house(pos, has_chimney, has_awning)


func _add_house(pos: Vector2, has_chimney: bool, has_awning: bool) -> void:
	var faces_positive_z: bool = pos.y < 0.0 # z<0 houses face +Z (toward the lane center)
	var front_sign: float = 1.0 if faces_positive_z else -1.0

	var house := Node3D.new()
	house.name = "House_%d_%d" % [int(pos.x), int(pos.y)]
	house.position = Vector3(pos.x, 0.0, pos.y)
	add_child(house)

	# Wall.
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = HOUSE_WALL_SIZE
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = COLOR_WALL
	wall_mesh.material = wall_mat

	var wall_visual := MeshInstance3D.new()
	wall_visual.name = "Wall"
	wall_visual.mesh = wall_mesh
	wall_visual.position = Vector3(0.0, HOUSE_WALL_SIZE.y * 0.5, 0.0)
	house.add_child(wall_visual)

	# Roof (symmetric gable — PrismMesh at left_to_right=0.5 centers the ridge).
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(HOUSE_WALL_SIZE.x + HOUSE_ROOF_OVERHANG, HOUSE_ROOF_HEIGHT, HOUSE_WALL_SIZE.z + HOUSE_ROOF_OVERHANG)
	roof_mesh.left_to_right = 0.5
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = COLOR_ROOF
	roof_mesh.material = roof_mat

	var roof_visual := MeshInstance3D.new()
	roof_visual.name = "Roof"
	roof_visual.mesh = roof_mesh
	var roof_peak: float = HOUSE_WALL_SIZE.y + HOUSE_ROOF_HEIGHT
	roof_visual.position = Vector3(0.0, HOUSE_WALL_SIZE.y + HOUSE_ROOF_HEIGHT * 0.5, 0.0)
	house.add_child(roof_visual)

	# One solid collision box spanning wall + attic space — simple and robust.
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(HOUSE_WALL_SIZE.x, roof_peak, HOUSE_WALL_SIZE.z)
	shape.shape = box_shape
	shape.position = Vector3(0.0, roof_peak * 0.5, 0.0)
	body.add_child(shape)
	house.add_child(body)

	# Honey window quad (emissive) + a low-energy glow, on the lane-facing wall.
	var window_mesh := BoxMesh.new()
	window_mesh.size = WINDOW_SIZE
	var window_mat := StandardMaterial3D.new()
	window_mat.albedo_color = COLOR_WINDOW
	window_mat.emission_enabled = true
	window_mat.emission = COLOR_WINDOW
	window_mat.emission_energy_multiplier = 1.6
	window_mesh.material = window_mat

	var window_visual := MeshInstance3D.new()
	window_visual.name = "Window"
	window_visual.mesh = window_mesh
	window_visual.position = Vector3(0.0, WINDOW_Y, front_sign * (HOUSE_WALL_SIZE.z * 0.5 + 0.03))
	house.add_child(window_visual)

	var window_light := OmniLight3D.new()
	window_light.name = "WindowGlow"
	window_light.light_color = COLOR_WINDOW
	window_light.light_energy = 0.6
	window_light.omni_range = 2.5
	window_light.position = window_visual.position
	house.add_child(window_light)

	if has_chimney:
		_add_chimney(house, front_sign, roof_peak)
	if has_awning:
		_add_awning(house, front_sign)


func _add_chimney(house: Node3D, front_sign: float, roof_peak: float) -> void:
	var local_pos: Vector3 = Vector3(0.5, roof_peak + CHIMNEY_SIZE.y * 0.5, front_sign * -0.3)
	var mesh := BoxMesh.new()
	mesh.size = CHIMNEY_SIZE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_ROOF_DARK
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "Chimney"
	visual.mesh = mesh
	visual.position = local_pos
	house.add_child(visual)

	var body := StaticBody3D.new()
	body.name = "ChimneyBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = CHIMNEY_SIZE
	shape.shape = box_shape
	shape.position = local_pos
	body.add_child(shape)
	house.add_child(body)

	var chimney_top: float = roof_peak + CHIMNEY_SIZE.y
	_d04_position = house.position + Vector3(local_pos.x, chimney_top + DREAMLING_CLEARANCE, local_pos.z)


func _add_awning(house: Node3D, front_sign: float) -> void:
	var local_pos: Vector3 = Vector3(0.0, AWNING_Y, front_sign * (HOUSE_WALL_SIZE.z * 0.5 + AWNING_SIZE.z * 0.5))
	_add_box_platform_local(house, "Awning", local_pos, AWNING_SIZE, COLOR_ROOF)

	var awning_top: float = AWNING_Y + AWNING_SIZE.y * 0.5
	_d02_position = house.position + Vector3(local_pos.x, awning_top + DREAMLING_CLEARANCE, local_pos.z)


## Same shape as _add_box_platform but parented under `parent` (a house node)
## at a LOCAL position, so awnings move with their house if repositioned.
func _add_box_platform_local(parent: Node3D, platform_name: String, local_pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = platform_name
	visual.mesh = mesh
	visual.position = local_pos
	parent.add_child(visual)

	var body := StaticBody3D.new()
	body.name = platform_name + "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = local_pos
	body.add_child(shape)
	parent.add_child(body)


# --- Purr thermals -----------------------------------------------------------

func _build_purr_thermals() -> void:
	_thermal_a = _add_purr_thermal(THERMAL_A_POS, 0.0)
	_add_purr_thermal(THERMAL_B_POS, THERMAL_B_PHASE)


func _add_purr_thermal(base_position: Vector3, phase_offset: float) -> PurrThermal:
	var thermal := PurrThermal.new()
	thermal.name = "PurrThermal"
	thermal.radius = THERMAL_RADIUS
	thermal.height = THERMAL_HEIGHT
	thermal.phase_offset = phase_offset
	thermal.position = base_position
	add_child(thermal)
	return thermal


# --- Rooftop chain -------------------------------------------------------------

func _build_rooftop_chain() -> void:
	for i: int in range(CLUSTER_A.size()):
		_add_box_platform("RoofA%d" % i, CLUSTER_A[i], Vector3(ROOF_SIZE.x, ROOF_THICKNESS, ROOF_SIZE.y), COLOR_ROOF)
	for i: int in range(CLUSTER_B.size()):
		_add_box_platform("RoofB%d" % i, CLUSTER_B[i], Vector3(ROOF_SIZE.x, ROOF_THICKNESS, ROOF_SIZE.y), COLOR_ROOF)


# --- Tail bridge ---------------------------------------------------------------

func _build_tail_bridge() -> void:
	_tail_bridge = TailBridge.new()
	_tail_bridge.name = "TailBridge"
	_tail_bridge.pivot = TAIL_PIVOT
	_tail_bridge.arm_length = TAIL_ARM_LENGTH
	_tail_bridge.yaw_range_degrees = TAIL_YAW_RANGE_DEGREES
	_tail_bridge.period = TAIL_PERIOD
	_tail_bridge.footprint = TAIL_FOOTPRINT
	_tail_bridge.thickness = TAIL_THICKNESS
	_tail_bridge.surface_color = COLOR_CAT
	# Set BEFORE add_child (bramble's breathing_chest.gd pattern): TailBridge's
	# own _ready() does not run synchronously inside add_child(), so anything
	# parented to it (d06) would otherwise briefly resolve to world origin
	# (0,0,0) instead of the arc's starting point — see tail_bridge.gd's class doc.
	_tail_bridge.position = TailBridge.arc_position(TAIL_PIVOT, TAIL_ARM_LENGTH, TAIL_YAW_RANGE_DEGREES, 0.0, TAIL_PERIOD, 0.0)
	add_child(_tail_bridge)


# --- Flank steps -----------------------------------------------------------------

func _build_flank_steps() -> void:
	for i: int in range(FLANK_STEPS.size()):
		_add_box_platform("FlankStep%d" % i, FLANK_STEPS[i], FLANK_STEP_SIZE, COLOR_CAT_DARK)


# --- Ridge shelf (convergence point) ----------------------------------------------

func _build_ridge_shelf() -> void:
	_add_box_platform("RidgeShelf", SHELF_POSITION, SHELF_SIZE, COLOR_CAT_DARK)


# --- Back ridge ------------------------------------------------------------------

func _build_ridge() -> void:
	_add_mound("Ridge", RIDGE_CENTER, RIDGE_RADIUS, COLOR_CAT)


# --- Rooftop garden (d09) ----------------------------------------------------------

func _build_garden() -> void:
	var surface_y: float = _sphere_surface_y(RIDGE_CENTER, RIDGE_RADIUS, GARDEN_ANCHOR_X, GARDEN_ANCHOR_Z)
	var center: Vector3 = Vector3(GARDEN_ANCHOR_X, surface_y, GARDEN_ANCHOR_Z)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_ROOF_DARK
	for i: int in range(GARDEN_POT_COUNT):
		var angle: float = TAU * float(i) / float(GARDEN_POT_COUNT)
		var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * GARDEN_POT_SPREAD
		var pot_center: Vector3 = center + offset + Vector3(0.0, GARDEN_POT_HEIGHT * 0.5, 0.0)

		var mesh := CylinderMesh.new()
		mesh.top_radius = GARDEN_POT_RADIUS
		mesh.bottom_radius = GARDEN_POT_RADIUS * 1.2
		mesh.height = GARDEN_POT_HEIGHT
		mesh.material = mat

		var visual := MeshInstance3D.new()
		visual.name = "GardenPot"
		visual.mesh = mesh
		visual.position = pot_center
		add_child(visual)

		var body := StaticBody3D.new()
		body.name = "GardenPotBody"
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var cyl_shape := CylinderShape3D.new()
		cyl_shape.radius = GARDEN_POT_RADIUS
		cyl_shape.height = GARDEN_POT_HEIGHT
		shape.shape = cyl_shape
		shape.position = pot_center
		body.add_child(shape)
		add_child(body)


# --- Head + ears + DreamDoor -------------------------------------------------------

func _build_head_and_ears() -> void:
	_add_mound("Head", HEAD_CENTER, HEAD_RADIUS, COLOR_CAT)

	var left_anchor_y: float = _sphere_surface_y(HEAD_CENTER, HEAD_RADIUS, EAR_ANCHOR_X, EAR_LEFT_Z)
	var right_anchor_y: float = _sphere_surface_y(HEAD_CENTER, HEAD_RADIUS, EAR_ANCHOR_X, EAR_RIGHT_Z)
	_add_ear(Vector3(EAR_ANCHOR_X, left_anchor_y + EAR_BUMP_HEIGHT, EAR_LEFT_Z))
	_add_ear(Vector3(EAR_ANCHOR_X, right_anchor_y + EAR_BUMP_HEIGHT, EAR_RIGHT_Z))

	var door_anchor_y: float = _sphere_surface_y(HEAD_CENTER, HEAD_RADIUS, EAR_ANCHOR_X, 0.0)
	var door: DreamDoor = DREAM_DOOR_SCENE.instantiate() as DreamDoor
	door.name = "DreamDoor"
	door.position = Vector3(EAR_ANCHOR_X, door_anchor_y + EAR_DOOR_LIFT, 0.0)
	add_child(door)


func _add_ear(ear_top: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = EAR_BUMP_RADIUS
	mesh.height = EAR_BUMP_RADIUS * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_CAT_DARK
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "Ear"
	visual.mesh = mesh
	visual.position = ear_top
	add_child(visual)

	var body := StaticBody3D.new()
	body.name = "EarBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = EAR_BUMP_RADIUS
	shape.shape = sphere_shape
	shape.position = ear_top
	body.add_child(shape)
	add_child(body)


# --- Dreamlings --------------------------------------------------------------------

func _build_dreamlings() -> void:
	var mid_a: Vector3 = CLUSTER_A[2] # d03 — mid rooftop chain
	var open_flank: Vector3 = FLANK_STEPS[2] # d05 — open, on the paw steps
	var garden_surface_y: float = _sphere_surface_y(RIDGE_CENTER, RIDGE_RADIUS, GARDEN_ANCHOR_X, GARDEN_ANCHOR_Z)
	var d10_surface_y: float = _sphere_surface_y(HEAD_CENTER, HEAD_RADIUS, D10_ANCHOR_X, D10_ANCHOR_Z)

	var positions: Dictionary = {
		"d01": Vector3(-63.0, 0.55, -3.0), # village square, near spawn
		"d02": _d02_position, # low awning — the first jump
		"d03": Vector3(mid_a.x, mid_a.y + ROOF_THICKNESS * 0.5 + DREAMLING_CLEARANCE, mid_a.z),
		"d04": _d04_position, # chimney top
		"d05": Vector3(open_flank.x, open_flank.y + FLANK_STEP_SIZE.y * 0.5 + DREAMLING_CLEARANCE, open_flank.z),
		"d08": Vector3(SHELF_POSITION.x, SHELF_POSITION.y + SHELF_SIZE.y * 0.5 + DREAMLING_CLEARANCE, SHELF_POSITION.z),
		"d09": Vector3(GARDEN_ANCHOR_X, garden_surface_y + 0.35, GARDEN_ANCHOR_Z), # hidden among the pots
		"d10": Vector3(D10_ANCHOR_X, d10_surface_y + 0.35, D10_ANCHOR_Z), # beside the ear door
	}

	for id: String in positions.keys():
		_add_dreamling(id, positions[id], self)

	# d06 rides the tail tip — parented to the tail bridge, so it sweeps with it.
	var tail_top_local: Vector3 = Vector3(0.0, TAIL_THICKNESS * 0.5 + 0.3, 0.0)
	_add_dreamling("d06", tail_top_local, _tail_bridge)

	# d07 rides the purr thermal — parented to it (the column's Area3D has no
	# world-geometry collider beneath the dreamling to stand on; parenting
	# mirrors d06's moving-platform pattern and matches check_placements.gd's
	# documented moving_platform exemption, see tools/props/check_placements.gd).
	var thermal_top_local: Vector3 = Vector3(0.0, THERMAL_HEIGHT - DREAMLING_CLEARANCE, 0.0)
	_add_dreamling("d07", thermal_top_local, _thermal_a)


func _add_dreamling(id: String, local_position: Vector3, parent: Node3D) -> void:
	var dreamling: Dreamling = DREAMLING_SCENE.instantiate() as Dreamling
	dreamling.name = "Dreamling_" + id
	dreamling.id = id
	dreamling.position = local_position
	parent.add_child(dreamling)


# --- Camera hints ------------------------------------------------------------------

func _build_camera_hints() -> void:
	# Yaw convention: 0 deg = default -Z forward; -90 deg = +X; +90 deg = -X
	# (bramble.gd's integration notes, docs/verify/worlds-VERIFY.md).
	_add_camera_hint("VillageApproachHint", Vector3(-50.0, 6.0, 0.0), Vector3(70.0, 15.0, 70.0), -90.0, 0, 1.0)
	_add_camera_hint("RooftopRunHint", Vector3(-3.0, 7.0, -1.0), Vector3(42.0, 15.0, 26.0), -90.0, 1, 0.8)
	_add_camera_hint("BackRidgeHint", Vector3(24.0, 9.0, 0.0), Vector3(32.0, 22.0, 26.0), -90.0, 2, 0.8)
	_add_camera_hint("SummitHint", Vector3(50.0, 14.0, 0.0), Vector3(30.0, 20.0, 26.0), 90.0, 3, 0.8)


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


# --- Dressing M2 props -------------------------------------------------------

func _build_dressing() -> void:
	for i: int in MUSHROOM_LAMP_POSITIONS.size():
		_add_dressing_prop("MushroomLamp%d" % i, "mushroom_lamp", MUSHROOM_LAMP_HEIGHT, MUSHROOM_LAMP_POSITIONS[i],
			_dressing_sphere(0.2, COLOR_WINDOW))

	for i: int in BERRY_BUSH_POSITIONS.size():
		_add_dressing_prop("BerryBush%d" % i, "berry_bush", BERRY_BUSH_HEIGHT, BERRY_BUSH_POSITIONS[i],
			_dressing_sphere(0.4, Color("6E8F6A")))

	_add_dressing_prop("PicnicBasketVisual", "picnic_basket", PICNIC_BASKET_HEIGHT, PICNIC_BASKET_POSITION,
		_dressing_box(Vector3(0.5, 0.3, 0.35), COLOR_ROOF))

	for house_index: int in MOTH_SMALL_HOUSE_INDICES:
		_add_rooftop_moth(HOUSE_LAYOUT[house_index] as Array)


## Perches a static moth_small on a house's roof slope, just off the ridge
## line so it doesn't sit exactly on d02/d04's own placements (both of
## which are on chimneys/awnings, never on the bare roof slope itself).
func _add_rooftop_moth(house_entry: Array) -> void:
	var house_x: float = house_entry[0]
	var house_z: float = house_entry[1]
	var roof_peak: float = HOUSE_WALL_SIZE.y + HOUSE_ROOF_HEIGHT
	var perch: Vector3 = Vector3(house_x + 0.4, roof_peak + 0.1, house_z + 0.3)
	_add_dressing_prop("RooftopMoth_%d_%d" % [int(house_x), int(house_z)], "moth_small", MOTH_SMALL_HEIGHT, perch,
		_dressing_sphere(0.08, Color("F5F2E8")))


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
## ModelSlot swap hides the primitive. No collision -- see the const block's
## doc comment above.
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
