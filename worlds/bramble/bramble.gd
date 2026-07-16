class_name Bramble
extends WorldBase
## Bramble — the first world (PITCH.md, GAME_BRIEF.md): a bear the size of
## a hill, asleep in a dusk meadow. Body runs along +X from the meadow-edge
## spawn: haunch mound -> breathing chest plateau -> shoulder -> head, with
## the EAR (the DreamDoor) on top at the far end. Two snore geysers near the
## snout, two foreleg paw ramps flanking the chest, ten dreamlings placed
## per the D12 dense-cadence rule (see docs/verify/worlds-VERIFY.md for the
## full d01-d10 route table). Grey-box: primitive meshes, flat
## StandardMaterial3D colors from ART_BIBLE.md only.

const DREAMLING_SCENE: PackedScene = preload("res://worlds/common/dreamling.tscn")
const DREAM_DOOR_SCENE: PackedScene = preload("res://worlds/common/dream_door.tscn")

# --- Palette (ART_BIBLE.md) ---------------------------------------------
const COLOR_MEADOW: Color = Color("7C9082") # sage in moonlight
const COLOR_MOAT: Color = Color(0.404, 0.463, 0.420) # darker sage, the boundary dip
const COLOR_FUR: Color = Color("8A6552") # warm umber
const COLOR_FUR_DARK: Color = Color("6E4F3E") # darker umber (paws, fur patches, ear)

# --- Meadow ---------------------------------------------------------------
const MEADOW_SIZE: Vector2 = Vector2(140.0, 80.0) # X: -70..70, Z: -40..40
const MOAT_SIZE: Vector2 = Vector2(190.0, 130.0)
# Below RESCUE_FLOOR_Y on purpose: stepping off the meadow must always end
# in the Soft Landing, never in a pit a 1.5 m jump can't escape (design
# floor: gentle rescue, no stuck states). The dark ring reads as the night
# beyond the meadow.
const MOAT_TOP_Y: float = -9.0
const MOAT_THICKNESS: float = 1.0
const RESCUE_FLOOR_Y: float = -8.0

# --- Spawns (meadow edge, arriving from the fort direction, facing +X) ---
const SPAWN_PIP: Vector3 = Vector3(-55.0, 0.5, 0.0)
const SPAWN_OTTO: Vector3 = Vector3(-57.0, 0.5, 2.0)

# --- Bear anatomy, along +X (tail/haunch -> head) --------------------------
const HAUNCH_CENTER: Vector3 = Vector3(-30.0, -6.0, 0.0)
const HAUNCH_RADIUS: float = 16.0 # top height = center.y + radius = 10.0 m

const CHEST_POSITION: Vector3 = Vector3(-5.0, 6.75, 0.0) # box center; rest top = 7.5 m
const CHEST_FOOTPRINT: Vector2 = Vector2(12.0, 8.0) # ~8 m wide, per brief
const CHEST_THICKNESS: float = 1.5
const CHEST_AMPLITUDE: float = 0.6
const CHEST_PERIOD: float = 5.0
const CHEST_PEDESTAL_MARGIN: float = 1.0
const CHEST_PEDESTAL_CLEARANCE: float = 0.3 # below the chest's lowest travel
const CHEST_PEDESTAL_THICKNESS: float = 2.0

const SHOULDER_CENTER: Vector3 = Vector3(20.0, -4.5, 0.0)
const SHOULDER_RADIUS: float = 14.0 # top height = 9.5 m

const HEAD_CENTER: Vector3 = Vector3(48.0, -5.0, 0.0)
const HEAD_RADIUS: float = 17.0 # top height = 12.0 m

# Ear anchor point on the head surface, plus a small bump rising to it.
const EAR_ANCHOR_X: float = 50.0
const EAR_ANCHOR_Z: float = 6.0
const EAR_BUMP_HEIGHT: float = 2.2 # anchor surface + this ~= 13 m, per brief
const EAR_BUMP_RADIUS: float = 1.8

# Snore geysers near the snout (front-top of the head).
const GEYSER_ANCHOR_X: float = 54.0
const GEYSER_ANCHOR_Z: float = 4.0
const GEYSER_RADIUS: float = 1.2
const GEYSER_HEIGHT: float = 8.0
const GEYSER_ACTIVE_DURATION: float = 1.2
const GEYSER_CYCLE_PERIOD: float = 5.0

# Foreleg paw ramps flanking the chest — the natural walk-up.
const PAW_RUN: float = 20.0 # horizontal length
const PAW_RISE: float = 2.6 # within the 1-3 m brief
const PAW_WIDTH: float = 5.0
const PAW_START_X: float = -15.0
const PAW_Z_OFFSET: float = 16.0

# Shoulder shelf (d08) — reachable by Otto-toss (~2.2 m apex, SPEC.md) or a
# chest-bounce jump; never toss-only, per the solo-completable floor rule.
const SHELF_ANCHOR_X: float = 24.0
const SHELF_ANCHOR_Z: float = 6.0
const SHELF_HEIGHT_ABOVE_ANCHOR: float = 3.2
const SHELF_SIZE: Vector3 = Vector3(3.0, 0.6, 3.0)

# Fur patches (tall-grass placeholders; d09 hides in the first one).
const FUR_PATCH_HAUNCH_X: float = -27.0
const FUR_PATCH_HAUNCH_Z: float = 6.0
const FUR_PATCH_BACK_X: float = -18.0
const FUR_PATCH_BACK_Z: float = -10.0
const FUR_BLADE_COUNT: int = 7
const FUR_PATCH_SPREAD: float = 1.6
const FUR_BLADE_HEIGHT: float = 0.9

# --- Ambient warm fill + wind grass (D22 graphics-v2, visual-only) ---------
const FIREFLY_FILL_POSITION: Vector3 = Vector3(-22.0, 3.6, -2.0) # matches core/env/ambience.gd's firefly_center
const FIREFLY_FILL_COLOR: Color = Color("F2C879")
# Both clear of the haunch mound's footprint (r16 from x=-30,z=0 — the same
# hazard bramble.gd's own d02 comment already flags for prop placement).
const GRASS_PATCH_A_CENTER: Vector3 = Vector3(-52.0, 0.0, -8.0) # meadow approach, near spawn
const GRASS_PATCH_B_CENTER: Vector3 = Vector3(-2.0, 0.0, 25.0) # open meadow flank, past the geysers/paw ramps
const GRASS_PATCH_SIZE: Vector2 = Vector2(14.0, 10.0)
const GRASS_DENSITY: int = 220

# --- Breath-becomes-weather (M2 set piece #1, worlds/bramble/breath_weather.gd) --
# Flat meadow near the snout's X coordinate but offset in Z -- see
# breath_weather.gd's own placement-note comment for why z=24 instead of
# z=0 (dead ahead of the snout is still on the head sphere's slope).
const BREATH_UPDRAFT_POSITION: Vector3 = Vector3(58.0, 0.0, 24.0)

# --- ROUND 2 additions: bear-direction warm fill + patchy meadow ground ----
# Note 5 ("warm bramble up"): a sleeping animal is warm -- a broad, low-
# energy warm wash centered over the chest/back, distinct from the small
# tight FireflyAreaGlow above (that one lights the fireflies cloud; this one
# is meant to read as ambient warmth radiating off the bear's whole body).
const BEAR_WARM_FILL_POSITION: Vector3 = Vector3(CHEST_POSITION.x, CHEST_POSITION.y + 3.0, CHEST_POSITION.z)
const BEAR_WARM_FILL_COLOR: Color = Color("D9A468") # between umber fur and honey firefly glow
const BEAR_WARM_FILL_ENERGY: float = 0.4
const BEAR_WARM_FILL_RANGE: float = 42.0
# Note 2 ("flat single-color ground"): sage <-> warm moss, a near-neighbor
# pair per the recipe (assets/shaders/ground_patches.gdshader).
const GROUND_TINT_A: Color = COLOR_MEADOW
const GROUND_TINT_B: Color = Color("8C9463")

var _chest: BreathingChest = null
var _geyser_a: SnoreGeyser = null # d07 rides this column (placement exemption)


func _ready() -> void:
	_build_meadow()
	_build_haunch()
	_build_chest()
	_build_shoulder()
	_build_head()
	_build_ear_and_door()
	_build_geysers()
	_build_paw_ramps()
	_build_fur_patches()
	_build_dreamlings()
	_build_camera_hints()
	_build_home_door()
	_build_ambient_lighting()
	_build_grass_fields()
	_build_bear_shell() # before _build_rollover: the sequence looks it up
	_build_breath_weather()
	_build_rollover()
	_build_dreamkeepers()
	_build_dressing()


# --- The readable bear (producer note: the roll-over must READ) --------------
# A bear-proportioned mesh can never drape the 111m x 12m mound chain
# (9:1 — the mounds were never bear-shaped). V1: the visible, keystone-
# performing bear sleeps beside the ear door at the level's east end; the
# mounds remain his blanketed bulk. Full terrain-rebuild-around-him is an
# M3 card. Rigged scene preferred (keystone clips); static GLB fallback.

const BEAR_SHELL_POSITION: Vector3 = Vector3(44.0, 0.0, 27.0) # toss-turn envelope stays on the meadow
const BEAR_SHELL_HEIGHT: float = 13.0 # static-fallback lying height
const BEAR_SHELL_RIG_STANDING_HEIGHT: float = 28.0 # rig is T-pose; sleep clip lies him down
const BEAR_SHELL_YAW_DEGREES: float = 0.0 # tuned by still
const BEAR_SHELL_RIG_SCENE: String = "res://scenes/players/rigs/bramble_bear_rig_rig.tscn"


func _build_bear_shell() -> void:
	var anchor := Node3D.new()
	anchor.name = "BearShellAnchor"
	anchor.position = BEAR_SHELL_POSITION
	anchor.rotation_degrees.y = BEAR_SHELL_YAW_DEGREES
	add_child(anchor)

	# Soft collision so nobody walks inside him (visual mesh has none).
	var body := StaticBody3D.new()
	body.name = "BearShellBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 7.0
	capsule.height = 22.0
	shape.shape = capsule
	shape.rotation_degrees = Vector3(90.0, 90.0, 0.0) # lying along X
	shape.position = Vector3(0.0, 5.0, 0.0)
	body.add_child(shape)
	anchor.add_child(body)

	# Rigged giant preferred (keystone clips); static GLB shell fallback.
	if ResourceLoader.exists(BEAR_SHELL_RIG_SCENE):
		var packed: PackedScene = load(BEAR_SHELL_RIG_SCENE)
		var rig: Node3D = packed.instantiate() as Node3D
		if rig != null:
			rig.name = "BearRig"
			var mesh_instance: MeshInstance3D = _find_first_mesh(rig)
			if mesh_instance != null and mesh_instance.mesh != null:
				# Mesh-local AABB only — the glTF importer bakes a 0.01
				# scale on the Armature that skinning already accounts for
				# (rigged_model_slot.gd's 90m-giant lesson).
				var aabb: AABB = mesh_instance.mesh.get_aabb()
				if aabb.size.y > 0.0:
					var s: float = BEAR_SHELL_RIG_STANDING_HEIGHT / aabb.size.y
					rig.scale = Vector3.ONE * s
					rig.position.y = -aabb.position.y * s * 0.0 # clips keep feet at origin
			anchor.add_child(rig)
			var player: AnimationPlayer = rig.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if player == null:
				for child: Node in rig.get_children():
					if child is AnimationPlayer:
						player = child
						break
			if player != null and player.has_animation("sleep"):
				player.play("sleep")
			print("MODEL_SWAP %s" % JSON.stringify({"id": "bramble_bear_rig", "rigged": true, "keystone": true}))
			return

	var slot := ModelSlot.new()
	slot.name = "BearShellSlot"
	slot.model_id = "bramble_bear"
	slot.target_height = BEAR_SHELL_HEIGHT
	anchor.add_child(slot)


func _find_first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child: Node in node.get_children():
		var found: MeshInstance3D = _find_first_mesh(child)
		if found != null:
			return found
	return null


# --- Dreamkeepers (M2, director wire-up of the dormant data file) ------------

const DREAMKEEPER_SCENE: PackedScene = preload("res://worlds/common/dreamkeeper.tscn")
const DREAMKEEPER_DATA_PATH_FORMAT: String = "res://data/dreamkeepers/%s.json"


func _build_dreamkeepers() -> void:
	var path: String = DREAMKEEPER_DATA_PATH_FORMAT % world_id()
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_warning("Bramble: dreamkeeper data at %s did not parse to a Dictionary" % path)
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
		push_warning("Bramble: dreamkeeper entry '%s' has no valid 'pos' -- skipped" % String(entry.get("id", "?")))
		return
	var pos_arr: Array = pos_raw as Array
	var keeper: Dreamkeeper = DREAMKEEPER_SCENE.instantiate() as Dreamkeeper
	keeper.name = "Dreamkeeper_%s" % String(entry.get("id", "keeper"))
	# Set BEFORE add_child (established codebase ordering -- see
	# dreamkeeper.gd's own header).
	keeper.keeper_id = String(entry.get("id", ""))
	keeper.rig_id = String(entry.get("rig", ""))
	keeper.face_yaw_degrees = float(entry.get("face_yaw", 0.0))
	keeper.position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
	add_child(keeper)


# --- Dressing (M2 batch-2 props; all visual-only walk-through, fort's
# convention -- zero route interference with harness choreography) -----------

const MOON_DAISY_POSITIONS: Array[Vector3] = [
	Vector3(-52.0, 0.0, -6.0), Vector3(-45.0, 0.0, 20.0),
	Vector3(-35.0, 0.0, 26.0), Vector3(-58.0, 0.0, 18.0),
]
const CLOVER_POSITIONS: Array[Vector3] = [
	Vector3(-50.0, 0.0, -20.0), Vector3(-38.0, 0.0, 18.0),
	Vector3(-25.0, 0.0, -30.0), Vector3(-15.0, 0.0, 32.0),
]
const MUSHROOM_LAMP_POSITIONS: Array[Vector3] = [
	Vector3(-60.0, 0.0, -8.0), Vector3(-48.0, 0.0, 14.0), Vector3(-62.0, 0.0, 10.0),
]
const SEED_PUFF_POSITIONS: Array[Vector3] = [
	Vector3(55.0, 0.0, 20.0), Vector3(60.0, 0.0, 28.0), Vector3(52.0, 0.0, 26.0),
]
const PINE_BIG_POSITIONS: Array[Vector3] = [
	Vector3(-66.0, 0.0, -30.0), Vector3(-66.0, 0.0, 30.0),
]
const PINE_SMALL_POSITIONS: Array[Vector3] = [
	Vector3(-64.0, 0.0, -18.0), Vector3(-30.0, 0.0, 34.0), Vector3(5.0, 0.0, -36.0),
]
const STONE_POSITIONS: Array[Vector3] = [
	Vector3(10.0, 0.0, -34.0), Vector3(-8.0, 0.0, 36.0),
]


func _build_dressing() -> void:
	for i: int in MOON_DAISY_POSITIONS.size():
		_add_dressing_prop("MoonDaisy%d" % i, "moon_daisy", 0.4, MOON_DAISY_POSITIONS[i],
			_dressing_sphere(0.15, Color("FFF3C4")))
	for i: int in CLOVER_POSITIONS.size():
		_add_dressing_prop("CloverTuft%d" % i, "clover_tuft", 0.3, CLOVER_POSITIONS[i],
			_dressing_sphere(0.15, Color("6E8F6A")))
	for i: int in MUSHROOM_LAMP_POSITIONS.size():
		_add_dressing_prop("MushroomLamp%d" % i, "mushroom_lamp", 0.5, MUSHROOM_LAMP_POSITIONS[i],
			_dressing_sphere(0.25, Color("F2C879")))
	for i: int in SEED_PUFF_POSITIONS.size():
		_add_dressing_prop("SeedPuff%d" % i, "seed_puff", 0.35, SEED_PUFF_POSITIONS[i],
			_dressing_sphere(0.17, Color("F5F2E8")))
	for i: int in PINE_BIG_POSITIONS.size():
		_add_dressing_prop("SoftPine%d" % i, "soft_pine", 3.0, PINE_BIG_POSITIONS[i],
			_dressing_cone(1.0, 3.0, Color("7C9082")))
	for i: int in PINE_SMALL_POSITIONS.size():
		_add_dressing_prop("SoftPineSmall%d" % i, "soft_pine_small", 1.8, PINE_SMALL_POSITIONS[i],
			_dressing_cone(0.6, 1.8, Color("7C9082")))
	for i: int in STONE_POSITIONS.size():
		_add_dressing_prop("StoneSoft%d" % i, "stone_soft", 0.7, STONE_POSITIONS[i],
			_dressing_sphere(0.35, Color(0.55, 0.58, 0.52)))
	_add_dressing_prop("StumpDoor", "stump_door", 0.8, Vector3(-68.0, 0.0, 0.0),
		_dressing_sphere(0.4, Color("6E4F3E")))
	_add_dressing_prop("HaystackPillow", "haystack_pillow", 0.8, Vector3(30.0, 0.0, 28.0),
		_dressing_sphere(0.4, Color("E8C97A")))


func _add_dressing_prop(anchor_name: String, prop_model_id: String, prop_height: float, prop_position: Vector3, primitive_mesh: Mesh) -> void:
	var anchor := Node3D.new()
	anchor.name = anchor_name
	anchor.position = prop_position
	add_child(anchor)

	var visual := MeshInstance3D.new()
	visual.name = "Primitive"
	visual.mesh = primitive_mesh
	visual.position = Vector3(0.0, prop_height * 0.5, 0.0)
	anchor.add_child(visual)

	var slot := ModelSlot.new()
	slot.name = "ModelSlot"
	slot.model_id = prop_model_id
	slot.target_height = prop_height
	anchor.add_child(slot)


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
	super._ready()


## Warm practical fill at the fireflies area (recipe: "warm fill lights at
## practicals ... bramble fireflies area") — bramble had no warm light
## source before this (only the cool moon key from core/env/ambience.gd),
## so this is the one this world's own script needed to add, unlike
## pillow_fort/marmalade whose porch/window lights already existed.
func _build_ambient_lighting() -> void:
	var light := OmniLight3D.new()
	light.name = "FireflyAreaGlow"
	light.light_color = FIREFLY_FILL_COLOR
	light.light_energy = 0.5
	light.omni_range = 7.0
	light.position = FIREFLY_FILL_POSITION
	add_child(light)

	# ROUND 2 (director's note 5): broad warm wash from the bear's own body,
	# distinct from the point-source firefly glow above.
	var bear_fill := OmniLight3D.new()
	bear_fill.name = "BearWarmFill"
	bear_fill.light_color = BEAR_WARM_FILL_COLOR
	bear_fill.light_energy = BEAR_WARM_FILL_ENERGY
	bear_fill.omni_range = BEAR_WARM_FILL_RANGE
	bear_fill.position = BEAR_WARM_FILL_POSITION
	add_child(bear_fill)


## Wind-swayed grass patches (assets/shaders/wind_sway.gdshader via
## core/env/grass_field.gd) — visual only, no collision, planted in the
## meadow the way the recipe asks ("plant fields in bramble's meadow
## areas"). Deterministic seeds so screenshot/harness receipts stay stable.
func _build_grass_fields() -> void:
	_add_grass_patch("GrassPatchA", GRASS_PATCH_A_CENTER, 1)
	_add_grass_patch("GrassPatchB", GRASS_PATCH_B_CENTER, 2)


## ROUND 2 (director's note 1, "grass reads as cold dark spikes"): dropped
## the fur-lerp tint (it muddied toward COLOR_FUR_DARK, a big part of why
## this read cold/brown instead of like sage lawn) and the taller 0.4 m
## override -- GrassField's own class defaults are now exactly the spec's
## "#7C9082 base toward #9DB39A tips", short/wide/clumped, so this patch
## just uses them.
func _add_grass_patch(patch_name: String, center: Vector3, rng_seed: int) -> void:
	var field := GrassField.new()
	field.name = patch_name
	add_child(field)
	field.scatter(center, GRASS_PATCH_SIZE, GRASS_DENSITY, rng_seed)


## M2 set piece #1 ("the breath becomes weather"): the ambient, always-on
## Divine-Beast body-function. See worlds/bramble/breath_weather.gd.
func _build_breath_weather() -> void:
	var weather := BreathWeather.new()
	weather.name = "BreathWeather"
	weather.position = BREATH_UPDRAFT_POSITION
	add_child(weather)


## M2 set piece #2 ("THE ROLL-OVER"): the one-time transformative
## Divine-Beast body-function. See worlds/bramble/rollover_sequence.gd.
## Wired after _build_haunch() (called earlier in _ready()) so the Haunch/
## HaunchBody nodes it settles already exist.
func _build_rollover() -> void:
	var rollover := RolloverSequence.new()
	rollover.name = "RolloverSequence"
	# setup() BEFORE add_child(): entering the tree fires _ready()
	# synchronously, so a reversed order would run _ready() with _world/
	# _haunch_visual/_haunch_body still unset (caught live: SCRIPT ERROR
	# "Invalid access to property... on a base object of type 'Nil'" at
	# rollover_sequence.gd's _ready(), see bramble-setpieces-VERIFY.md).
	rollover.setup(self, get_node("Haunch") as MeshInstance3D, get_node("HaunchBody") as StaticBody3D)
	add_child(rollover)


func world_id() -> String:
	return "bramble"


func spawn_points() -> Dictionary:
	var facing_bear: Basis = Basis.looking_at(Vector3.RIGHT, Vector3.UP) # +X, toward the bear
	return {
		"pip": Transform3D(facing_bear, SPAWN_PIP),
		"otto": Transform3D(facing_bear, SPAWN_OTTO),
	}


func objective_ids() -> Array[String]:
	return ["d01", "d02", "d03", "d04", "d05", "d06", "d07", "d08", "d09", "d10"] as Array[String]


func rescue_floor_y() -> float:
	return RESCUE_FLOOR_Y


## The way home: a doorframe at the meadow edge behind spawn, facing the
## bear, so leaving is always one interact away (worlds are never gated).
func _build_home_door() -> void:
	var door := WorldDoor.new()
	door.name = "HomeDoor"
	door.target_world = "pillow_fort"
	door.position = Vector3(SPAWN_PIP.x - 6.0, 0.0, 1.0)
	door.rotation_degrees = Vector3(0.0, 90.0, 0.0) # opening faces the bear (+X)
	door.exit_requested.connect(func() -> void:
		exit_requested_to.emit("pillow_fort")
		exit_requested.emit()
	)
	add_child(door)


# --- Geometry helpers -------------------------------------------------------

## Height of a sphere mound's surface directly above world (x, z); 0 if that
## point is outside the sphere's footprint. Used to anchor props exactly on
## a mound's surface instead of hand-guessing elevations.
func _sphere_surface_y(center: Vector3, radius: float, x: float, z: float) -> float:
	var dx: float = x - center.x
	var dz: float = z - center.z
	var under_sqrt: float = radius * radius - dx * dx - dz * dz
	if under_sqrt < 0.0:
		return center.y
	return center.y + sqrt(under_sqrt)


func _build_meadow() -> void:
	_add_ground_slab("Moat", MOAT_SIZE, MOAT_TOP_Y, MOAT_THICKNESS, COLOR_MOAT)
	_add_ground_slab("Meadow", MEADOW_SIZE, 0.0, 1.0, COLOR_MEADOW)
	# ROUND 2 (director's note 2): the meadow is the world's main walkable
	# ground -- give it the patchy sage/warm-moss shader (the moat stays
	# flat: it's a boundary void ring, not gameplay ground). Override on the
	# MeshInstance3D (not the BoxMesh resource): PrimitiveMesh only exposes a
	# single `.material` property, not ArrayMesh's per-surface setter.
	(get_node("Meadow") as MeshInstance3D).set_surface_override_material(0, _ground_patch_material(GROUND_TINT_A, GROUND_TINT_B))


## D22 graphics-v2 ROUND 2, assets/shaders/ground_patches.gdshader (director's
## note 2): builds a ShaderMaterial pre-loaded with a world's near-neighbor
## tint pair.
func _ground_patch_material(tint_a: Color, tint_b: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ground_patches.gdshader") as Shader
	mat.set_shader_parameter("tint_a", tint_a)
	mat.set_shader_parameter("tint_b", tint_b)
	return mat


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


func _build_haunch() -> void:
	_add_mound("Haunch", HAUNCH_CENTER, HAUNCH_RADIUS, COLOR_FUR)


func _build_chest() -> void:
	_chest = BreathingChest.new()
	_chest.name = "Chest"
	_chest.footprint = CHEST_FOOTPRINT
	_chest.thickness = CHEST_THICKNESS
	_chest.amplitude = CHEST_AMPLITUDE
	_chest.period = CHEST_PERIOD
	_chest.surface_color = COLOR_FUR
	_chest.position = CHEST_POSITION
	add_child(_chest)

	# Static pedestal beneath so there is never a hole under the plank, even
	# at the lowest point of its breath.
	var lowest_top: float = (CHEST_POSITION.y + CHEST_THICKNESS * 0.5) - CHEST_AMPLITUDE
	var pedestal_top: float = lowest_top - CHEST_PEDESTAL_CLEARANCE
	var pedestal_footprint: Vector2 = CHEST_FOOTPRINT + Vector2(CHEST_PEDESTAL_MARGIN, CHEST_PEDESTAL_MARGIN) * 2.0
	_add_ground_slab("ChestPedestal", pedestal_footprint, pedestal_top, CHEST_PEDESTAL_THICKNESS,
		COLOR_FUR_DARK, Vector2(CHEST_POSITION.x, CHEST_POSITION.z))


func _build_shoulder() -> void:
	_add_mound("Shoulder", SHOULDER_CENTER, SHOULDER_RADIUS, COLOR_FUR)
	_build_shelf()


func _build_shelf() -> void:
	var anchor_y: float = _sphere_surface_y(SHOULDER_CENTER, SHOULDER_RADIUS, SHELF_ANCHOR_X, SHELF_ANCHOR_Z)
	var shelf_center: Vector3 = Vector3(SHELF_ANCHOR_X, anchor_y + SHELF_HEIGHT_ABOVE_ANCHOR, SHELF_ANCHOR_Z)

	var mesh := BoxMesh.new()
	mesh.size = SHELF_SIZE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_FUR_DARK
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "ShoulderShelf"
	visual.mesh = mesh
	visual.position = shelf_center
	add_child(visual)

	var body := StaticBody3D.new()
	body.name = "ShoulderShelfBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = SHELF_SIZE
	shape.shape = box_shape
	shape.position = shelf_center
	body.add_child(shape)
	add_child(body)


func _build_head() -> void:
	_add_mound("Head", HEAD_CENTER, HEAD_RADIUS, COLOR_FUR)


func _build_ear_and_door() -> void:
	var anchor_y: float = _sphere_surface_y(HEAD_CENTER, HEAD_RADIUS, EAR_ANCHOR_X, EAR_ANCHOR_Z)
	var ear_top: Vector3 = Vector3(EAR_ANCHOR_X, anchor_y + EAR_BUMP_HEIGHT, EAR_ANCHOR_Z)

	var mesh := SphereMesh.new()
	mesh.radius = EAR_BUMP_RADIUS
	mesh.height = EAR_BUMP_RADIUS * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_FUR_DARK
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

	var door: DreamDoor = DREAM_DOOR_SCENE.instantiate() as DreamDoor
	door.name = "DreamDoor"
	door.position = ear_top
	add_child(door)


func _build_geysers() -> void:
	var geyser_y: float = _sphere_surface_y(HEAD_CENTER, HEAD_RADIUS, GEYSER_ANCHOR_X, GEYSER_ANCHOR_Z)
	_geyser_a = _add_geyser(Vector3(GEYSER_ANCHOR_X, geyser_y, GEYSER_ANCHOR_Z), 1.0)
	_add_geyser(Vector3(GEYSER_ANCHOR_X, geyser_y, -GEYSER_ANCHOR_Z), 3.5)


func _add_geyser(base_position: Vector3, phase_offset: float) -> SnoreGeyser:
	var geyser := SnoreGeyser.new()
	geyser.name = "SnoreGeyser"
	geyser.radius = GEYSER_RADIUS
	geyser.height = GEYSER_HEIGHT
	geyser.active_duration = GEYSER_ACTIVE_DURATION
	geyser.cycle_period = GEYSER_CYCLE_PERIOD
	geyser.phase_offset = phase_offset
	geyser.position = base_position
	add_child(geyser)
	return geyser


func _build_paw_ramps() -> void:
	_add_paw_ramp(PAW_Z_OFFSET)
	_add_paw_ramp(-PAW_Z_OFFSET)


func _add_paw_ramp(z_offset: float) -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(PAW_RUN, PAW_RISE, PAW_WIDTH)
	mesh.left_to_right = 1.0 # ridge at +X: surface rises as local X increases
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_FUR_DARK
	mesh.material = mat

	var ramp_position: Vector3 = Vector3(PAW_START_X + PAW_RUN * 0.5, PAW_RISE * 0.5, z_offset)

	var visual := MeshInstance3D.new()
	visual.name = "PawRamp"
	visual.mesh = mesh
	visual.position = ramp_position
	add_child(visual)

	var body := StaticBody3D.new()
	body.name = "PawRampBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	shape.position = ramp_position
	body.add_child(shape)
	add_child(body)


func _build_fur_patches() -> void:
	var haunch_y: float = _sphere_surface_y(HAUNCH_CENTER, HAUNCH_RADIUS, FUR_PATCH_HAUNCH_X, FUR_PATCH_HAUNCH_Z)
	_add_fur_patch(Vector3(FUR_PATCH_HAUNCH_X, haunch_y, FUR_PATCH_HAUNCH_Z))
	var back_y: float = _sphere_surface_y(HAUNCH_CENTER, HAUNCH_RADIUS, FUR_PATCH_BACK_X, FUR_PATCH_BACK_Z)
	_add_fur_patch(Vector3(FUR_PATCH_BACK_X, back_y, FUR_PATCH_BACK_Z))


func _add_fur_patch(center: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_FUR_DARK
	for i: int in range(FUR_BLADE_COUNT):
		var offset: Vector2 = Vector2(randf_range(-FUR_PATCH_SPREAD, FUR_PATCH_SPREAD), randf_range(-FUR_PATCH_SPREAD, FUR_PATCH_SPREAD))
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, FUR_BLADE_HEIGHT, 0.12)
		mesh.material = mat

		var blade := MeshInstance3D.new()
		blade.name = "FurBlade"
		blade.mesh = mesh
		blade.position = center + Vector3(offset.x, FUR_BLADE_HEIGHT * 0.5 - 0.1, offset.y)
		blade.rotation.y = randf_range(0.0, TAU)
		add_child(blade)


func _build_dreamlings() -> void:
	var positions: Dictionary = {
		"d01": Vector3(-48.0, 0.55, 3.0), # meadow approach, near spawn
		# Clear of the haunch mound's footprint (r16 from x-30,z0): the
		# original (-40, -6) sat INSIDE the hill — buried and unreachable.
		"d02": Vector3(-42.0, 0.55, -14.0), # meadow approach, south side
		"d03": Vector3(3.0, 2.7, PAW_Z_OFFSET), # on the +Z paw ramp
		"d04": Vector3(3.0, 2.7, -PAW_Z_OFFSET), # on the -Z paw ramp
		"d05": Vector3(HAUNCH_CENTER.x, HAUNCH_CENTER.y + HAUNCH_RADIUS + 0.3, 0.0), # haunch peak, first plateau
		"d08": Vector3(SHELF_ANCHOR_X, 0.0, SHELF_ANCHOR_Z), # y filled in below, on the shoulder shelf
		"d09": Vector3(FUR_PATCH_HAUNCH_X, 0.0, FUR_PATCH_HAUNCH_Z), # y filled in below, hidden in fur
		# P3 fix (docs/verify/properties-VERIFY.md): was EAR_ANCHOR_Z - 1.5,
		# which sat 1.50 m from the ear-bump sphere's center -- inside its
		# 1.8 m radius, i.e. embedded. -2.3 clears the bump (radius 1.8 +
		# dreamling clearance 0.35 = 2.15 m required, 2.30 m actual) while
		# staying close enough to read as "in the ear hollow" beside the
		# DreamDoor, y still anchored on the bump surface below.
		"d10": Vector3(EAR_ANCHOR_X, 0.0, EAR_ANCHOR_Z - 2.3),
	}
	positions["d08"].y = _sphere_surface_y(SHOULDER_CENTER, SHOULDER_RADIUS, SHELF_ANCHOR_X, SHELF_ANCHOR_Z) + SHELF_HEIGHT_ABOVE_ANCHOR + 0.6
	positions["d09"].y = _sphere_surface_y(HAUNCH_CENTER, HAUNCH_RADIUS, FUR_PATCH_HAUNCH_X, FUR_PATCH_HAUNCH_Z) + 0.35
	positions["d10"].y = _sphere_surface_y(HEAD_CENTER, HEAD_RADIUS, EAR_ANCHOR_X, EAR_ANCHOR_Z) + EAR_BUMP_HEIGHT

	for id: String in positions.keys():
		_add_dreamling(id, positions[id], self)

	# d06 rides the chest: parented to it, so it moves with the breath.
	var chest_top_local: Vector3 = Vector3(0.0, CHEST_THICKNESS * 0.5 + 0.3, 0.0)
	_add_dreamling("d06", chest_top_local, _chest)

	# d07 rides the +Z snore geyser: parented to the column (the marmalade
	# thermal exemption pattern) so the placement property understands it —
	# a dreamling atop an updraft has no ground beneath by design.
	_add_dreamling("d07", Vector3(0.0, GEYSER_HEIGHT - 0.3, 0.0), _geyser_a)


func _add_dreamling(id: String, local_position: Vector3, parent: Node3D) -> void:
	var dreamling: Dreamling = DREAMLING_SCENE.instantiate() as Dreamling
	dreamling.name = "Dreamling_" + id
	dreamling.id = id
	dreamling.position = local_position
	parent.add_child(dreamling)


func _build_camera_hints() -> void:
	# Yaw convention: 0 deg = default -Z forward (Godot's identity facing);
	# -90 deg = +X; +90 deg = -X (see integration notes in worlds-VERIFY.md).
	_add_camera_hint("MeadowApproachHint", Vector3(-35.0, 7.5, 0.0), Vector3(70.0, 15.0, 80.0), -90.0, 0, 1.0)
	_add_camera_hint("ClimbHint", Vector3(10.0, 12.5, 0.0), Vector3(50.0, 25.0, 40.0), -90.0, 1, 0.8)
	_add_camera_hint("HeadEarHint", Vector3(52.5, 15.0, 0.0), Vector3(35.0, 30.0, 40.0), 90.0, 2, 0.8)


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
