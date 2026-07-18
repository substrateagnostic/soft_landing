class_name Tortoise
extends WorldBase
## Tortoise — the fourth world (docs/design/world-cards/tortoise.md): the
## oldest giant, asleep so long a whole garden grew over her shell. Layout is
## RADIAL rather than linear like Bramble/Wisp/Marmalade's along-+X anatomy
## paths: a meadow skirt at ground level surrounds one big buried dome (her
## shell), and a spiral ascent of four terraced garden tiers (Tier1 -> Tier2
## -> Tier3 -> Crown) climbs up and around it, connected by long, gentle
## ramps (9-14 deg grades -- the gentlest of any world, matching the world
## card's "slowest, gentlest" register). Ten dreamlings placed per the card's
## d01-d10 mix (1 race, 1 ride, 1 shy, 1 duet, 1 flourish, 5 open). Grey-box
## fallback for every prop (D10 seam); the giant herself uses the already-
## generated assets/models/meshy/generated/tortoise_giant.glb via a plain
## ModelSlot (a tortoise is a quadruped -- Meshy can't rig it, same "static
## sculpt" precedent as Marmalade's cat / Wisp's whale-body mounds).
##
## Architecture note -- "the whole garden lifts skyward" (THE SLOW RISE,
## rise_sequence.gd): every dreamling in this file stays a DIRECT child of
## the world root (`self`), exactly like every other world -- never nested
## under a shared moving group -- so tools/props/check_placements.gd's
## `moving_platform` exemption (parent != world root) keeps applying only to
## the ONE dreamling that's genuinely supposed to be exempt (d07, which
## rides the BreathingBloom perch), not accidentally to all ten. Instead,
## every top-level rising piece (the shell, each terrace ledge + ramp, the
## crown bloom, the DreamDoor, terrace dressing) is ALSO appended to
## `_garden_nodes` as it's built; rise_sequence.gd tweens `position:y` on
## every entry in that array by the same delta, in parallel -- visually
## identical to a single shared parent, zero risk to the established
## per-dreamling placement-checking convention.

const DREAMLING_SCENE: PackedScene = preload("res://worlds/common/dreamling.tscn")
const DREAM_DOOR_SCENE: PackedScene = preload("res://worlds/common/dream_door.tscn")
const DREAMKEEPER_SCENE: PackedScene = preload("res://worlds/common/dreamkeeper.tscn")
const DREAMKEEPER_DATA_PATH_FORMAT: String = "res://data/dreamkeepers/%s.json"

# --- Palette (docs/design/world-cards/tortoise.md, verbatim hexes) ---------
const COLOR_SHELL: Color = Color("8C9463") # moss-sage shell
const COLOR_MOSS: Color = Color("6E8F6A") # deep moss accents
const COLOR_HONEY: Color = Color("F2C879") # honey bloom glow
const COLOR_BLUSH: Color = Color("E8B4C8") # blush blooms
const COLOR_CREAM: Color = Color("F5F2E8") # cream
const COLOR_MEADOW: Color = Color("7C9082") # dusk-sage meadow
const COLOR_MEADOW_TINT_B: Color = Color("96A698") # lighter sage, ground-patches pair
const COLOR_TERRACE_STONE: Color = Color("8A6552") # warm soil/stone terrace edging
const COLOR_MOAT: Color = Color(0.404, 0.463, 0.420) # darker sage void (marmalade's own tone, reused)

# --- Ground / moat (bramble-moat pattern: void ring below the rescue line) -
const MEADOW_SIZE: Vector2 = Vector2(110.0, 90.0)
const MEADOW_CENTER: Vector2 = Vector2(16.0, 0.0)
const MEADOW_TOP_Y: float = 0.0
const MEADOW_THICKNESS: float = 1.0
const MOAT_SIZE: Vector2 = Vector2(220.0, 160.0)
const MOAT_TOP_Y: float = -9.0
const MOAT_THICKNESS: float = 1.0
const RESCUE_FLOOR_Y: float = -8.0

# --- Spawns (meadow's west edge, arriving from the fort direction, facing +X)
const SPAWN_PIP: Vector3 = Vector3(-30.0, 0.5, 0.0)
const SPAWN_OTTO: Vector3 = Vector3(-32.0, 0.5, 2.0)

# --- The shell: a big buried dome (walkable terrain collision the terraces
# hug), ~40 m footprint across (world card: "~35-45 m across"). Apex directly
# above (SHELL_CENTER.x, SHELL_CENTER.z) sits at SHELL_CENTER.y + SHELL_RADIUS
# = -14 + 26 = 12.0 m -- matches the other three worlds' own summit heights
# (Wisp's body crest 14 m, Marmalade's head 12 m).
const SHELL_CENTER: Vector3 = Vector3(32.0, -14.0, 0.0)
const SHELL_RADIUS: float = 26.0

# --- The giant herself (M4 giant treatment, matching Marmalade's cat / Wisp's
# whale-mound precedent exactly): assets/models/meshy/generated/
# tortoise_giant.glb via a plain ModelSlot (quadruped -- Meshy can't rig).
# GLB local AABB (measured via a throwaway --script tool, ModelSlot's own
# _compute_local_aabb technique): size (x=1.389, y=0.908, z=1.906), long axis
# local Z. SHELL_TARGET_HEIGHT=19.0 -> world Z length ~= 19.0*(1.906/0.908) =
# 39.9 m (dead center of the "35-45 m across" brief), world X width ~=
# 19.0*(1.389/0.908) = 29.1 m. Anchored so the model's grounded bottom
# (ModelSlot always grounds AABB-bottom to the anchor's own y) sits at
# SHELL_ANCHOR_POSITION.y = -7.0, top at -7.0+19.0 = 12.0 -- lines up with the
# terrain dome's own apex (SHELL_CENTER.y+SHELL_RADIUS=12.0) so the visible
# plush body reads as resting generously inside the walkable hill, the same
# "oversized, non-mesh-hugging collision the visible giant merely stands
# inside of" convention Bramble/Wisp/Marmalade's own giants already use.
const SHELL_ANCHOR_POSITION: Vector3 = Vector3(32.0, -7.0, 0.0)
const SHELL_TARGET_HEIGHT: float = 19.0
const SHELL_YAW_DEGREES: float = 0.0 # starting default -- tuned by still, same convention as every prior giant's own yaw comment

# Ambient breathing (visual only, on the shell's own visual anchor scale --
# NEVER the terrain collision, matching D25's mountain precedent: "static
# collision under subtle visual breathing"). "Her breathing sway is slower
# than Bramble's" (task brief) -- period well past every other world's own
# ambient-breath constant (Marmalade's CAT_BREATH_PERIOD=6.0), amplitude the
# smallest of any world.
const SHELL_BREATH_AMPLITUDE: float = 0.01 # +/-1% y-scale
const SHELL_BREATH_PERIOD: float = 14.0

# --- Terrace ascent (radial spiral, XZ anchors only -- Y always computed via
# _sphere_surface_y against SHELL_CENTER/RADIUS, matching every other world's
# own shelf/ledge convention). Distances-from-center step down as height
# climbs (20.25 -> 17.03 -> 12.04 -> 2.24 m), the natural "terraces get
# smaller near the top of a dome" shape. ---------------------------------
const ASCENT_BASE: Vector3 = Vector3(6.0, 0.0, -10.0) # meadow ground, where Ramp0 begins
const TIER1_ANCHOR: Vector2 = Vector2(13.0, -7.0) # d~20.25 -> y~2.31
const TIER2_ANCHOR: Vector2 = Vector2(21.0, 13.0) # d~17.03 -> y~5.65
const TIER3_ANCHOR: Vector2 = Vector2(41.0, 8.0) # d~12.04 -> y~9.04
const CROWN_ANCHOR: Vector2 = Vector2(34.0, -1.0) # d~2.24 -> y~11.90

# NOTE (caught live via tools/props/check_placements.gd --world=tortoise):
# the shell is a SOLID ball (SphereShape3D has no hollow interior), and at
# the outer tiers (Tier1 d~20, Tier2 d~17 -- close to the ball's own
# "equator" relative to its radius) the ball's local surface climbs steeply
# with lateral XZ distance from a ledge's own anchor point (>1m of rise
# across less than 2m of offset at Tier1). A flat ledge computed from ONE
# anchor sample plus a small clearance can therefore sit entirely below the
# ball's surface just a meter or two off that anchor -- exactly what FAILed
# (d03/d05/d08 all `inside_solid:true` on the first pass). Fixed by widening
# TERRACE_HEIGHT_ABOVE_ANCHOR (more buffer against the worst-case curvature
# across a ledge's own footprint) and pulling dreamling/dressing offsets in
# closer to each ledge's own anchor (TIER_OFFSET, smaller radius = smaller
# worst-case mismatch) -- re-verified 10/10 PASS after, see
# docs/verify/tortoise-world-VERIFY.md.
const TERRACE_HEIGHT_ABOVE_ANCHOR: float = 1.5 # bumped again -- d05 (Tier2) sat right at the ball's surface boundary and FLICKERED pass/fail run-to-run (ground_gap 0.0-0.19 across identical positions, Jolt's own float non-determinism at a razor's-margin point query) until this widened it to a firm, repeatable margin
const TIER1_LEDGE_SIZE: Vector3 = Vector3(7.0, 0.6, 7.0)
const TIER2_LEDGE_SIZE: Vector3 = Vector3(6.5, 0.6, 6.5)
const TIER3_LEDGE_SIZE: Vector3 = Vector3(6.5, 0.6, 6.5)
const CROWN_LEDGE_SIZE: Vector3 = Vector3(6.0, 0.6, 6.0)
const ASCENT_RAMP_WIDTH: float = 2.0 # narrowed again -- a ramp's own box collision is centered exactly on the ledge's anchor point at BOTH ends it touches, so any dreamling offset inside roughly half this width risks the same overlap d05/d08/d10 hit live
const ASCENT_RAMP_THICKNESS: float = 0.5
const DREAMLING_CLEARANCE: float = 0.3
const TIER_OFFSET: float = 0.9 # dreamling/dressing offset radius from a ledge's own anchor

# BreathingBloom perch (d07, the "flourish" -- Tortoise's answer to Bramble's
# snore-geyser / Wisp's water-spout / Marmalade's purr-thermal "rides a
# living breath" tradition), between Tier2 and Tier3.
const BLOOM_PERCH_ANCHOR: Vector2 = Vector2(28.0, 14.0) # d~14.56 -> y~7.54
const BLOOM_PERCH_HEIGHT_ABOVE_ANCHOR: float = 0.7

# Crown "highest bloom" bump (the DreamDoor's neighbor, mirrors Wisp's
# blowhole-rim / Marmalade's twin-ear pattern) -- offset from the crown ledge
# by >5 m so neither reads as clipping into the other.
const CROWN_BLOOM_ANCHOR: Vector2 = Vector2(38.0, -6.0) # d~8.49 -> y~10.58
const CROWN_BLOOM_BUMP_HEIGHT: float = 1.0
const CROWN_BLOOM_BUMP_RADIUS: float = 1.4

# THE SLOW RISE's persistent reward -- a small "highest bloom" nook, near the
# crown but clear of both the crown ledge (>7 m center-to-center) and the
# bloom bump (>12 m) -- built hidden by rise_sequence.gd itself; this file
# only supplies the XZ anchor its top surface is computed against.
const REWARD_ANCHOR: Vector2 = Vector2(29.0, 4.0) # d~5.0 -> y~11.51
const REWARD_HEIGHT_ABOVE_ANCHOR: float = 0.4

# --- Dressing M2 props (assets/models/meshy/generated/, tools/meshy/
# manifest.json target_height_hint values). Meadow dressing stays OUTSIDE
# `_garden_nodes` (fixed ground, never rises -- only the shell/terraces are
# "her"); terrace dressing rises WITH its tier. All positions checked by
# hand (>=1.5 m) against every dreamling/ledge/ramp/door placement below. ---
const SOFT_PINE_HEIGHT: float = 1.8
const SOFT_PINE_POSITIONS: Array[Vector3] = [
	Vector3(-24.0, 0.0, 8.0),
	Vector3(-14.0, 0.0, -9.0),
]
const BERRY_BUSH_HEIGHT: float = 0.9
const BERRY_BUSH_POSITIONS: Array[Vector3] = [
	Vector3(-22.0, 0.0, -6.0),
	Vector3(2.0, 0.0, -14.0),
]
const MEADOW_MOON_DAISY_POSITIONS: Array[Vector3] = [
	Vector3(-20.0, 0.0, 3.0),
	Vector3(-4.0, 0.0, 6.0),
]
const MEADOW_MOON_DAISY_HEIGHT: float = 0.4
const MEADOW_STONE_SOFT_POS: Vector3 = Vector3(-9.0, 0.0, -1.0)
const MEADOW_STONE_SOFT_HEIGHT: float = 0.7
const MEADOW_STONE_SOFT_COLLISION_RADIUS: float = 0.35
const MEADOW_SEED_PUFF_POS: Vector3 = Vector3(-26.0, 0.0, -2.0)
const MEADOW_SEED_PUFF_HEIGHT: float = 0.35

const TERRACE_MUSHROOM_LAMP_HEIGHT: float = 0.5
const TERRACE_BIRDHOUSE_LANTERN_HEIGHT: float = 0.6
const CLOVER_TUFT_HEIGHT: float = 0.3 # d08's hiding patch


var _shell_anchor: Node3D = null
var _shell_breath_time: float = randf() * 10.0
var _rise: RiseSequence = null

var _tier1_ledge_center: Vector3 = Vector3.ZERO
var _tier2_ledge_center: Vector3 = Vector3.ZERO
var _tier3_ledge_center: Vector3 = Vector3.ZERO
var _crown_ledge_center: Vector3 = Vector3.ZERO
var _bloom_perch: BreathingBloom = null
var _reward_top_point: Vector3 = Vector3.ZERO

var _garden_nodes: Array[Node3D] = []


func _ready() -> void:
	_build_meadow()
	_build_moat()
	_build_shell()
	_build_ascent_path()
	_build_crown()
	_build_breathing_bloom()
	_build_dreamlings()
	_build_camera_hints()
	_build_home_door()
	_build_dreamkeepers()
	_build_dressing()
	_build_rise() # after every garden node exists -- rise_sequence.gd reads garden_nodes()/reward_top_point()
	_build_dev_camera()
	super._ready()


## The shell's own always-on breathing sway (D25 mountain precedent: static
## terrain collision, subtle VISUAL breathing only) -- suppressed while
## RiseSequence is animating the same anchor's own position, matching
## marmalade.gd's `_stretch.playing` guard exactly, so the two never fight
## over one property.
func _process(delta: float) -> void:
	if _shell_anchor == null:
		return
	if _rise != null and _rise.playing:
		return
	_shell_breath_time += delta
	var s: float = 1.0 + sin(_shell_breath_time * TAU / SHELL_BREATH_PERIOD) * SHELL_BREATH_AMPLITUDE
	_shell_anchor.scale = Vector3(s, s, s)


func world_id() -> String:
	return "tortoise"


func spawn_points() -> Dictionary:
	var facing_shell: Basis = Basis.looking_at(Vector3.RIGHT, Vector3.UP) # +X, toward the shell
	return {
		"pip": Transform3D(facing_shell, SPAWN_PIP),
		"otto": Transform3D(facing_shell, SPAWN_OTTO),
	}


func objective_ids() -> Array[String]:
	return ["d01", "d02", "d03", "d04", "d05", "d06", "d07", "d08", "d09", "d10"] as Array[String]


func rescue_floor_y() -> float:
	return RESCUE_FLOOR_Y


## Read by rise_sequence.gd via setup() -- every top-level piece that should
## visually rise together as "the whole garden."
func garden_nodes() -> Array[Node3D]:
	return _garden_nodes


func reward_top_point() -> Vector3:
	return _reward_top_point


## The way home: a doorframe at the meadow's west edge behind spawn, facing
## the shell, so leaving is always one interact away (worlds are never
## gated). Mirrors wisp.gd/marmalade.gd's HomeDoor exactly.
func _build_home_door() -> void:
	var door := WorldDoor.new()
	door.name = "HomeDoor"
	door.target_world = "pillow_fort"
	door.frame_color = COLOR_SHELL
	door.position = Vector3(SPAWN_PIP.x - 6.0, 0.0, 1.0)
	door.rotation_degrees = Vector3(0.0, 90.0, 0.0) # opening faces the shell (+X)
	door.exit_requested.connect(func() -> void:
		exit_requested_to.emit("pillow_fort")
		exit_requested.emit()
	)
	add_child(door)


# --- Geometry helpers -------------------------------------------------------

## Height of the shell dome's surface directly above world (x, z); the dome's
## own center.y if that point is outside its footprint (bramble.gd's proven
## helper, verbatim pattern -- used here for every terrace/bump anchor).
func _sphere_surface_y(center: Vector3, radius: float, x: float, z: float) -> float:
	var dx: float = x - center.x
	var dz: float = z - center.z
	var under_sqrt: float = radius * radius - dx * dx - dz * dz
	if under_sqrt < 0.0:
		return center.y
	return center.y + sqrt(under_sqrt)


func _ground_patch_material(tint_a: Color, tint_b: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ground_patches.gdshader") as Shader
	mat.set_shader_parameter("tint_a", tint_a)
	mat.set_shader_parameter("tint_b", tint_b)
	return mat


## Static ground slab (bramble.gd's proven helper): a MeshInstance3D + a
## matching StaticBody3D, both parented to `self` -- used for the meadow and
## the moat, neither of which ever moves.
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


func _build_meadow() -> void:
	# D27 terrain v1 (bramble's template): rolling meadow heightfield. Flat
	# discs pin the spawn/HomeDoor clearing and the WHOLE shell footprint +
	# rim (terrace ramp feet land there — their authored y values must keep
	# meeting true ground). NOTE: flat-disc coordinates are LOCAL to the
	# patch node, which sits at MEADOW_CENTER — subtract it.
	var meadow := TerrainPatch.new()
	meadow.name = "Meadow"
	meadow.position = Vector3(MEADOW_CENTER.x, MEADOW_TOP_Y, MEADOW_CENTER.y)
	var flat_discs: Array[Vector3] = [
		Vector3(SPAWN_PIP.x - MEADOW_CENTER.x, SPAWN_PIP.z - MEADOW_CENTER.y, 8.0), # spawns + HomeDoor
		Vector3(SHELL_CENTER.x - MEADOW_CENTER.x, SHELL_CENTER.z - MEADOW_CENTER.y, SHELL_RADIUS + 3.0), # shell + rim + ramp feet
	]
	meadow.setup(MEADOW_SIZE, 0.35, 16.0, 5, flat_discs, 8.0, TerrainPatch.DEFAULT_RESOLUTION, 9.5)
	add_child(meadow)
	(get_node("Meadow") as MeshInstance3D).set_surface_override_material(0, _ground_patch_material(COLOR_MEADOW, COLOR_MEADOW_TINT_B))


## Below RESCUE_FLOOR_Y on purpose (bramble's moat lesson): stepping off the
## meadow's edge must always end in the Soft Landing, never on a walkable
## apron a jump can't escape.
func _build_moat() -> void:
	_add_ground_slab("Moat", MOAT_SIZE, MOAT_TOP_Y, MOAT_THICKNESS, COLOR_MOAT)


## The shell: the walkable terrain dome (big, generous, non-mesh-hugging --
## supports the whole terraced garden) plus the visible giant herself (a
## plain ModelSlot, grey-box sphere fallback matching Marmalade's own
## `_build_cat_giant()` split between "what you see" and "what you stand
## on"). Both halves join `_garden_nodes` -- when she stands, her literal
## body rises with the garden built on it.
func _build_shell() -> void:
	_build_shell_terrain()
	_build_shell_giant()


func _build_shell_terrain() -> void:
	var body := StaticBody3D.new()
	body.name = "ShellTerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = SHELL_RADIUS
	shape.shape = sphere_shape
	shape.position = SHELL_CENTER
	body.add_child(shape)
	add_child(body)
	_garden_nodes.append(body)


func _build_shell_giant() -> void:
	var anchor := Node3D.new()
	anchor.name = "ShellGiantAnchor"
	anchor.position = SHELL_ANCHOR_POSITION
	anchor.rotation_degrees.y = SHELL_YAW_DEGREES
	add_child(anchor)
	_shell_anchor = anchor
	_garden_nodes.append(anchor)

	var mesh := SphereMesh.new()
	mesh.radius = SHELL_TARGET_HEIGHT * 0.5
	mesh.height = SHELL_TARGET_HEIGHT
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_SHELL
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "Primitive"
	visual.mesh = mesh
	visual.position = Vector3(0.0, SHELL_TARGET_HEIGHT * 0.5, 0.0)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchor.add_child(visual)

	var slot := ModelSlot.new()
	slot.name = "ModelSlot"
	slot.model_id = "tortoise_giant"
	slot.target_height = SHELL_TARGET_HEIGHT
	anchor.add_child(slot)
	if slot.get_child_count() > 0:
		_disable_shadows_recursive(slot.get_child(0))


func _disable_shadows_recursive(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_disable_shadows_recursive(child)


# --- Terrace ledges + ramps (the ascent path) -------------------------------

## A flat garden-bed platform anchored on the shell's own surface (wisp/
## marmalade's shelf pattern). Returns the ledge's own center so callers
## (dreamling placement, ramp endpoints, dressing) can build on top of it
## exactly. Both the visual and its body join `_garden_nodes`.
func _add_terrace_ledge(ledge_name: String, anchor: Vector2, size: Vector3, color: Color) -> Vector3:
	var anchor_y: float = _sphere_surface_y(SHELL_CENTER, SHELL_RADIUS, anchor.x, anchor.y)
	var center: Vector3 = Vector3(anchor.x, anchor_y + TERRACE_HEIGHT_ABOVE_ANCHOR, anchor.y)

	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = ledge_name
	visual.mesh = mesh
	visual.position = center
	add_child(visual)
	visual.set_surface_override_material(0, _ground_patch_material(color, COLOR_MOSS))
	_garden_nodes.append(visual)

	var body := StaticBody3D.new()
	body.name = ledge_name + "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = center
	body.add_child(shape)
	add_child(body)
	_garden_nodes.append(body)

	return center


## A long, gentle ramp between two arbitrary 3D points (wisp.gd's
## `_add_whale_ramp` box-and-Basis.looking_at pattern -- deliberately NOT a
## PrismMesh+trimesh wedge like bramble's ascent ramps, so every terrace
## ramp stays a plain BoxShape3D and never trips check_placements.gd's own
## documented trimesh point-query caveat). Both halves join `_garden_nodes`.
func _add_terrace_ramp(ramp_name: String, from_point: Vector3, to_point: Vector3) -> void:
	var direction: Vector3 = to_point - from_point
	var length: float = direction.length()
	var mid: Vector3 = (from_point + to_point) * 0.5
	var ramp_basis: Basis = Basis.looking_at(direction.normalized(), Vector3.UP)

	var body := StaticBody3D.new()
	body.name = ramp_name + "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = Transform3D(ramp_basis, mid)
	add_child(body)
	_garden_nodes.append(body)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(ASCENT_RAMP_WIDTH, ASCENT_RAMP_THICKNESS, length)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_TERRACE_STONE
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = mesh
	body.add_child(visual)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = mesh.size
	shape.shape = box_shape
	body.add_child(shape)


func _build_ascent_path() -> void:
	_tier1_ledge_center = _add_terrace_ledge("Tier1Ledge", TIER1_ANCHOR, TIER1_LEDGE_SIZE, COLOR_SHELL)
	_tier2_ledge_center = _add_terrace_ledge("Tier2Ledge", TIER2_ANCHOR, TIER2_LEDGE_SIZE, COLOR_SHELL)
	_tier3_ledge_center = _add_terrace_ledge("Tier3Ledge", TIER3_ANCHOR, TIER3_LEDGE_SIZE, COLOR_SHELL)

	var tier1_top: Vector3 = _tier1_ledge_center + Vector3(0.0, TIER1_LEDGE_SIZE.y * 0.5, 0.0)
	var tier2_top: Vector3 = _tier2_ledge_center + Vector3(0.0, TIER2_LEDGE_SIZE.y * 0.5, 0.0)
	var tier3_top: Vector3 = _tier3_ledge_center + Vector3(0.0, TIER3_LEDGE_SIZE.y * 0.5, 0.0)

	_add_terrace_ramp("Ramp0", ASCENT_BASE, tier1_top)
	_add_terrace_ramp("Ramp1", tier1_top, tier2_top)
	_add_terrace_ramp("Ramp2", tier2_top, tier3_top)
	# Ramp3 (Tier3 -> Crown) is added by _build_crown() once the crown
	# ledge's own top is known.


## The summit: the crown ledge (Tier3's final destination), the "highest
## bloom" bump beside it, and the DreamDoor nested at the bloom -- mirrors
## wisp.gd's blowhole / marmalade.gd's twin-ear pattern exactly (door
## position = the bump's own center).
func _build_crown() -> void:
	_crown_ledge_center = _add_terrace_ledge("CrownLedge", CROWN_ANCHOR, CROWN_LEDGE_SIZE, COLOR_SHELL)
	var crown_top: Vector3 = _crown_ledge_center + Vector3(0.0, CROWN_LEDGE_SIZE.y * 0.5, 0.0)
	var tier3_top: Vector3 = _tier3_ledge_center + Vector3(0.0, TIER3_LEDGE_SIZE.y * 0.5, 0.0)
	_add_terrace_ramp("Ramp3", tier3_top, crown_top)

	var bloom_anchor_y: float = _sphere_surface_y(SHELL_CENTER, SHELL_RADIUS, CROWN_BLOOM_ANCHOR.x, CROWN_BLOOM_ANCHOR.y)
	var bump_center: Vector3 = Vector3(CROWN_BLOOM_ANCHOR.x, bloom_anchor_y + CROWN_BLOOM_BUMP_HEIGHT, CROWN_BLOOM_ANCHOR.y)

	var mesh := SphereMesh.new()
	mesh.radius = CROWN_BLOOM_BUMP_RADIUS
	mesh.height = CROWN_BLOOM_BUMP_RADIUS * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_BLUSH
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "CrownBloomBump"
	visual.mesh = mesh
	visual.position = bump_center
	add_child(visual)
	_garden_nodes.append(visual)

	var body := StaticBody3D.new()
	body.name = "CrownBloomBumpBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = CROWN_BLOOM_BUMP_RADIUS
	shape.shape = sphere_shape
	shape.position = bump_center
	body.add_child(shape)
	add_child(body)
	_garden_nodes.append(body)

	var door: DreamDoor = DREAM_DOOR_SCENE.instantiate() as DreamDoor
	door.name = "DreamDoor"
	door.position = bump_center
	add_child(door)
	_garden_nodes.append(door)

	var reward_anchor_y: float = _sphere_surface_y(SHELL_CENTER, SHELL_RADIUS, REWARD_ANCHOR.x, REWARD_ANCHOR.y)
	_reward_top_point = Vector3(REWARD_ANCHOR.x, reward_anchor_y + REWARD_HEIGHT_ABOVE_ANCHOR, REWARD_ANCHOR.y)


## d07's perch (the "flourish"): a small bloom bobbing gently on the shell's
## own slow breath, between Tier2 and Tier3.
func _build_breathing_bloom() -> void:
	var anchor_y: float = _sphere_surface_y(SHELL_CENTER, SHELL_RADIUS, BLOOM_PERCH_ANCHOR.x, BLOOM_PERCH_ANCHOR.y)
	_bloom_perch = BreathingBloom.new()
	_bloom_perch.name = "BreathingBloom"
	_bloom_perch.position = Vector3(BLOOM_PERCH_ANCHOR.x, anchor_y + BLOOM_PERCH_HEIGHT_ABOVE_ANCHOR, BLOOM_PERCH_ANCHOR.y)
	add_child(_bloom_perch)
	_garden_nodes.append(_bloom_perch)


# --- Dreamlings --------------------------------------------------------------

func _add_dreamling(id: String, local_position: Vector3, parent: Node3D) -> void:
	var dreamling: Dreamling = DREAMLING_SCENE.instantiate() as Dreamling
	dreamling.name = "Dreamling_" + id
	dreamling.id = id
	dreamling.position = local_position
	parent.add_child(dreamling)


## The mix (world card): 1 race (d01), 1 ride (d04), 1 duet (d05), 1
## flourish (d07, open+speak_on_collect -- see data/missions/tortoise.json),
## 1 shy (d08), 5 open (d02, d03, d06, d09, d10). Spread across meadow (2),
## Tier1 (1), Tier2 (2), between Tier2/Tier3 (1), Tier3 (2), Crown (2).
func _build_dreamlings() -> void:
	_add_dreamling("d01", Vector3(-18.0, 0.55, 4.0), self)
	_add_dreamling("d02", Vector3(-6.0, 0.55, -4.0), self)

	_add_dreamling("d03", _tier1_ledge_center + Vector3(TIER_OFFSET, TIER1_LEDGE_SIZE.y * 0.5 + DREAMLING_CLEARANCE, -TIER_OFFSET * 0.6), self)

	# Tier2 is the one ledge two ramps meet at (Ramp1 in, Ramp2 out), both
	# centered exactly on TIER2_ANCHOR's own top point -- d04/d05 sit well
	# off to either side in Z, clear of both ramps' shared connection point
	# (caught live via repeated check_placements.gd runs: an X-leaning offset
	# here kept landing inside one ramp or the other, or -- at a large enough
	# X to clear them -- inside the ball's own curved surface instead).
	_add_dreamling("d04", _tier2_ledge_center + Vector3(0.3, TIER2_LEDGE_SIZE.y * 0.5 + DREAMLING_CLEARANCE, TIER_OFFSET * 1.6), self)
	_add_dreamling("d05", _tier2_ledge_center + Vector3(-0.3, TIER2_LEDGE_SIZE.y * 0.5 + DREAMLING_CLEARANCE, -TIER_OFFSET * 1.6), self)

	# d07 rides the BreathingBloom perch (parented, local offset above it) --
	# the one dreamling in this world that IS a genuine moving-platform
	# exemption for check_placements.gd.
	_add_dreamling("d07", Vector3(0.0, 0.55, 0.0), _bloom_perch)

	# Tier3 is where both Ramp2 (arriving from Tier2, roughly -X) and Ramp3
	# (departing toward Crown, roughly -X/-Z) meet the ledge -- d08 originally
	# sat almost exactly on Ramp3's own departure point and FAILed placement
	# (`inside_solid:true`, caught live). Both d06 and d08 now sit on the +X
	# side of the ledge, clear of either ramp's own footprint.
	_add_dreamling("d06", _tier3_ledge_center + Vector3(TIER_OFFSET, TIER3_LEDGE_SIZE.y * 0.5 + DREAMLING_CLEARANCE, TIER_OFFSET * 0.6), self)
	_add_dreamling("d08", _tier3_ledge_center + Vector3(TIER_OFFSET, TIER3_LEDGE_SIZE.y * 0.5 + DREAMLING_CLEARANCE, -TIER_OFFSET * 0.6), self)

	_add_dreamling("d09", _crown_ledge_center + Vector3(-TIER_OFFSET, CROWN_LEDGE_SIZE.y * 0.5 + DREAMLING_CLEARANCE, TIER_OFFSET * 0.6), self)
	_add_dreamling("d10", _crown_ledge_center + Vector3(TIER_OFFSET * 1.1, CROWN_LEDGE_SIZE.y * 0.5 + DREAMLING_CLEARANCE, -TIER_OFFSET * 0.4), self)


# --- Camera hints ------------------------------------------------------------

func _build_camera_hints() -> void:
	# Yaw convention (bramble.gd, confirmed against core/camera/camera_hint.gd):
	# 0 deg = default -Z forward; -90 deg = +X; +90 deg = -X.
	_add_camera_hint("MeadowApproachHint", Vector3(-10.0, 8.0, -2.0), Vector3(70.0, 22.0, 60.0), -90.0, 0, 1.0)
	_add_camera_hint("LowerTerraceHint", Vector3(17.0, 8.0, 3.0), Vector3(40.0, 18.0, 40.0), -90.0, 1, 0.8)
	_add_camera_hint("UpperTerraceHint", Vector3(37.0, 12.0, 3.0), Vector3(30.0, 16.0, 30.0), -60.0, 2, 0.8)
	_add_camera_hint("CrownHint", Vector3(35.0, 14.0, -3.0), Vector3(20.0, 14.0, 20.0), 90.0, 3, 0.8)


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


# --- Dreamkeepers (the lamb visits the garden) -------------------------------

## Direct per-world spawn call (not a WorldBase._wire_* hook, matching wisp.gd/
## pillow_fort.gd's own convention). Data-driven from
## data/dreamkeepers/tortoise.json (schema: id, rig, pos, face_yaw). Placed on
## the fixed meadow (never on a rising terrace) -- simplest, matches how every
## other world's own dreamkeeper sits on that world's own non-moving ground.
func _build_dreamkeepers() -> void:
	var path: String = DREAMKEEPER_DATA_PATH_FORMAT % world_id()
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_warning("Tortoise: dreamkeeper data at %s did not parse to a Dictionary" % path)
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
		push_warning("Tortoise: dreamkeeper entry '%s' has no valid 'pos' -- skipped" % String(entry.get("id", "?")))
		return
	var pos_arr: Array = pos_raw as Array
	var keeper: Dreamkeeper = DREAMKEEPER_SCENE.instantiate() as Dreamkeeper
	keeper.name = "Dreamkeeper_%s" % String(entry.get("id", "keeper"))
	# Set BEFORE add_child -- dreamkeeper.gd's own header / wisp.gd's identical
	# comment / critter.gd's kind/world_id precedent.
	keeper.keeper_id = String(entry.get("id", ""))
	keeper.rig_id = String(entry.get("rig", ""))
	keeper.face_yaw_degrees = float(entry.get("face_yaw", 0.0))
	keeper.position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
	add_child(keeper)


# --- Dressing M2 props -------------------------------------------------------

func _dressing_sphere(radius: float, color: Color) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	return mesh


func _dressing_cone(radius: float, height: float, color: Color) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	return mesh


## Ground-anchored container (D10 pattern): `anchor` + the primitive mesh are
## the only two children until a ModelSlot swap hides the primitive. Returns
## the anchor so terrace callers can add it to `_garden_nodes`.
func _add_dressing_prop(anchor_name: String, model_id: String, target_height: float, prop_position: Vector3, primitive_mesh: Mesh, parent: Node3D = self) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = anchor_name
	anchor.position = prop_position
	parent.add_child(anchor)

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
	return anchor


## Simple static cylinder collider ("only stump_door + stone_soft + soft_pine
## get simple static collision cylinders" convention, matching wisp.gd/
## pillow_fort.gd verbatim).
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


func _build_dressing() -> void:
	_build_meadow_dressing()
	_build_terrace_dressing()


## Meadow dressing stays fixed (outside `_garden_nodes`) -- it's ground, not
## her.
func _build_meadow_dressing() -> void:
	for i: int in SOFT_PINE_POSITIONS.size():
		_add_dressing_prop("SoftPine%d" % i, "soft_pine_small", SOFT_PINE_HEIGHT, SOFT_PINE_POSITIONS[i],
			_dressing_cone(0.6, SOFT_PINE_HEIGHT, COLOR_MOSS))

	for i: int in BERRY_BUSH_POSITIONS.size():
		_add_dressing_prop("BerryBush%d" % i, "berry_bush", BERRY_BUSH_HEIGHT, BERRY_BUSH_POSITIONS[i],
			_dressing_sphere(0.4, COLOR_MOSS))

	for i: int in MEADOW_MOON_DAISY_POSITIONS.size():
		_add_dressing_prop("MeadowMoonDaisy%d" % i, "moon_daisy", MEADOW_MOON_DAISY_HEIGHT, MEADOW_MOON_DAISY_POSITIONS[i],
			_dressing_sphere(0.12, COLOR_CREAM))

	_add_dressing_prop("MeadowStoneSoft", "stone_soft", MEADOW_STONE_SOFT_HEIGHT, MEADOW_STONE_SOFT_POS,
		_dressing_sphere(MEADOW_STONE_SOFT_HEIGHT * 0.5, COLOR_TERRACE_STONE))
	_add_prop_cylinder_collision(MEADOW_STONE_SOFT_POS, MEADOW_STONE_SOFT_COLLISION_RADIUS, MEADOW_STONE_SOFT_HEIGHT)

	_add_dressing_prop("MeadowSeedPuff", "seed_puff", MEADOW_SEED_PUFF_HEIGHT, MEADOW_SEED_PUFF_POS,
		_dressing_sphere(0.14, COLOR_CREAM))


## Terrace dressing rises WITH its tier -- every anchor here joins
## `_garden_nodes`. A mushroom-lamp on Tier1, a birdhouse-lantern on Tier2, and
## a small clover-tuft cluster around d08 on Tier3 (the "hidden among the
## clover" shy patch, matching wisp/marmalade's own reed/pot hiding spots).
func _build_terrace_dressing() -> void:
	var lamp_anchor: Node3D = _add_dressing_prop(
		"Tier1MushroomLamp", "mushroom_lamp", TERRACE_MUSHROOM_LAMP_HEIGHT,
		_tier1_ledge_center + Vector3(-TIER_OFFSET, TIER1_LEDGE_SIZE.y * 0.5, TIER_OFFSET * 0.6),
		_dressing_sphere(0.25, COLOR_HONEY)
	)
	_garden_nodes.append(lamp_anchor)

	var lantern_anchor: Node3D = _add_dressing_prop(
		"Tier2BirdhouseLantern", "birdhouse_lantern", TERRACE_BIRDHOUSE_LANTERN_HEIGHT,
		_tier2_ledge_center + Vector3(TIER_OFFSET, TIER2_LEDGE_SIZE.y * 0.5, TIER_OFFSET),
		_dressing_sphere(0.3, COLOR_HONEY)
	)
	_garden_nodes.append(lantern_anchor)

	# Clustered around d08's own +X,-Z quadrant (see _build_dreamlings()'s own
	# comment on that offset) -- "hidden among the clover" only reads right if
	# the clover is actually near the shy dreamling it hides.
	var clover_positions: Array[Vector3] = [
		_tier3_ledge_center + Vector3(TIER_OFFSET * 0.5, TIER3_LEDGE_SIZE.y * 0.5, -TIER_OFFSET * 1.3),
		_tier3_ledge_center + Vector3(TIER_OFFSET * 1.3, TIER3_LEDGE_SIZE.y * 0.5, -TIER_OFFSET * 0.9),
		_tier3_ledge_center + Vector3(TIER_OFFSET * 0.9, TIER3_LEDGE_SIZE.y * 0.5, -TIER_OFFSET * 0.3),
	]
	for i: int in clover_positions.size():
		var clover_anchor: Node3D = _add_dressing_prop(
			"Tier3CloverTuft%d" % i, "clover_tuft", CLOVER_TUFT_HEIGHT, clover_positions[i],
			_dressing_sphere(0.15, COLOR_MOSS)
		)
		_garden_nodes.append(clover_anchor)


# --- THE SLOW RISE keystone --------------------------------------------------

## setup() BEFORE add_child() -- established codebase ordering (bramble.gd's
## own _build_rollover() comment: entering the tree fires _ready()
## synchronously, so a reversed order would run RiseSequence._ready() with
## its own refs still unset).
func _build_rise() -> void:
	_rise = RiseSequence.new()
	_rise.name = "RiseSequence"
	_rise.setup(self, garden_nodes(), reward_top_point())
	add_child(_rise)


# --- Layout-iteration tool (mirrors wisp.gd/bramble.gd's own
# _build_dev_camera() verbatim): a static free camera for framing stills
# while placing the shell/terrace geometry. Inert unless --devcam is passed.
func _build_dev_camera() -> void:
	var devcam_flag: Variant = Harness.flag("devcam", false)
	if devcam_flag == false or devcam_flag == null:
		return
	var cam := Camera3D.new()
	cam.name = "DevCam"
	add_child(cam)
	cam.position = _parse_vec3(str(Harness.flag("devcam_pos", "")), Vector3(20.0, 35.0, 90.0))
	cam.look_at(_parse_vec3(str(Harness.flag("devcam_look", "")), Vector3(30.0, 6.0, 0.0)), Vector3.UP)
	cam.fov = float(str(Harness.flag("devcam_fov", "60")))
	cam.current = true
	print("DEVCAM %s" % JSON.stringify({"pos": [cam.position.x, cam.position.y, cam.position.z]}))


func _parse_vec3(s: String, fallback: Vector3) -> Vector3:
	var parts: PackedStringArray = s.split(",")
	if parts.size() < 3:
		return fallback
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
