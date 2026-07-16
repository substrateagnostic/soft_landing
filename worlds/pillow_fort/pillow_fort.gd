class_name PillowFort
extends WorldBase
## PillowFort — the hub (PITCH.md, GAME_BRIEF.md). A cozy dusk clearing at
## the foot of the first giant: a blanket-box fort with a lantern-lit
## interior, a couple of cushion mounds, low fence posts, and a doorway at
## the back that looks out across the clearing toward Bramble's distant
## silhouette — "from the fort's doorway you can see the whole skyline of
## sleeping giants." Zero objectives in v0.1 (fort growth is Phase 5);
## WorldBase already guards zero-objective worlds against auto-completing.

const CLEARING_SIZE: Vector2 = Vector2(25.0, 25.0)
const CLEARING_COLOR: Color = Color("7C9082") # sage in moonlight
# ROUND 2 (director's note 2): near-neighbor tint pair for the ground-
# patches shader -- sage <-> a lighter, blanket-soft variant.
const CLEARING_GROUND_TINT_B: Color = Color("96A698")

const FORT_CENTER: Vector3 = Vector3(0.0, 0.0, -6.0)
const FORT_WIDTH: float = 4.5
const FORT_DEPTH: float = 4.5
const FORT_HEIGHT: float = 3.0
const WALL_THICKNESS: float = 0.25
const DOOR_WIDTH: float = 1.6 # ART_BIBLE fort door scale
const FORT_WALL_COLOR: Color = Color("F5F2E8") # milk white
const FORT_GLOW_COLOR: Color = Color("F2C879") # honey glow

const CUSHION_BLUSH: Color = Color("E8B4C8")
const CUSHION_DUSK_BLUE: Color = Color("2E3B5E")

const CALLIE_SCENE: PackedScene = preload("res://core/companion/callie.tscn")
const CALLIE_CUSHION_RADIUS: float = 0.32
const CALLIE_CUSHION_HEIGHT_SCALE: float = 0.55 # squashed flatter than the walkable cushions (_add_cushion)

const FENCE_POST_COUNT: int = 8
const FENCE_POST_RADIUS: float = 11.5 # just inside the clearing edge
const FENCE_POST_HEIGHT: float = 0.9
const FENCE_POST_COLOR: Color = Color("8A6552")

const BEAR_SILHOUETTE_POSITION: Vector3 = Vector3(0.0, 3.0, -85.0)
const BEAR_SILHOUETTE_RADIUS: float = 14.0
const BEAR_SILHOUETTE_COLOR: Color = Color(0.35, 0.33, 0.32) # grey-umber, unreachable — just shape

const RESCUE_FLOOR_Y: float = -10.0


func _ready() -> void:
	_build_clearing()
	_build_fort()
	_build_cushions()
	_build_fence()
	_build_bear_silhouette()
	_build_camera_hint()
	_build_bramble_door()
	_build_fort_growth()
	_build_callie_home()
	super._ready()


## The fort remembers (D14): every growth stage adds something warm.
## Stage 1: night-light orbs over the doorway. Stage 2: a firefly jar by
## the door. Stage 3: a dream mobile above the roof. Built from the saved
## GameState.fort_stage, so it's there when you come home.
func _build_fort_growth() -> void:
	var stage: int = GameState.fort_stage
	if stage >= 1:
		# Strung over the doorway at a kid's eye line, not up on the roof
		# where the auto-camera crops them out.
		for i: int in range(3):
			_add_glow_orb(
				"NightLight%d" % i,
				FORT_CENTER + Vector3(-0.9 + 0.9 * i, FORT_HEIGHT * 0.72, FORT_DEPTH * 0.5 + 0.12),
				0.16
			)
	if stage >= 2:
		# FireflyJarVisual is the ground-anchored container ModelSlot needs
		# (D10): it and the grey-box jar mesh are the only two children.
		var jar_anchor := Node3D.new()
		jar_anchor.name = "FireflyJarVisual"
		jar_anchor.position = FORT_CENTER + Vector3(DOOR_WIDTH, 0.0, FORT_DEPTH * 0.5 + 0.4)
		add_child(jar_anchor)

		var jar := MeshInstance3D.new()
		jar.name = "FireflyJar"
		var jar_mesh := CylinderMesh.new()
		jar_mesh.top_radius = 0.18
		jar_mesh.bottom_radius = 0.22
		jar_mesh.height = 0.35
		var jar_mat := StandardMaterial3D.new()
		jar_mat.albedo_color = FORT_GLOW_COLOR
		jar_mat.emission_enabled = true
		jar_mat.emission = FORT_GLOW_COLOR
		jar_mat.emission_energy_multiplier = 1.4
		jar_mesh.material = jar_mat
		jar.mesh = jar_mesh
		jar.position = Vector3(0.0, jar_mesh.height * 0.5, 0.0) # rests on jar_anchor's ground
		jar_anchor.add_child(jar)

		var jar_slot := ModelSlot.new()
		jar_slot.name = "FireflyJarModelSlot"
		jar_slot.model_id = "firefly_jar"
		jar_slot.target_height = 0.35 # ART_BIBLE scale rules: firefly_jar 0.35
		jar_anchor.add_child(jar_slot)
	if stage >= 3:
		for i: int in range(4):
			var angle: float = TAU * i / 4.0
			_add_glow_orb(
				"MobileDream%d" % i,
				FORT_CENTER + Vector3(cos(angle) * 0.8, FORT_HEIGHT + 1.3, sin(angle) * 0.8),
				0.12
			)


func _add_glow_orb(orb_name: String, orb_position: Vector3, radius: float) -> void:
	var orb := MeshInstance3D.new()
	orb.name = orb_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("FFF3C4")
	mat.emission_enabled = true
	mat.emission = Color("FFF3C4")
	mat.emission_energy_multiplier = 2.0
	mesh.material = mat
	orb.mesh = mesh
	orb.position = orb_position
	add_child(orb)


## The stuffed cat's home cushion (docs/design/world-cards/callie.md), beside
## the fort's right side wall. Guarded against duplicating a Callie who is
## still going to exist (core/companion/callie.gd's own static
## active_instance bookkeeping + will_persist() — read-only from here, see
## that script's header/method comments for the full world-switch-survival
## trace, including why a plain `state == CARRIED` or is_instance_valid()
## check isn't enough).
func _build_callie_home() -> void:
	if Callie.active_instance != null and is_instance_valid(Callie.active_instance) \
			and Callie.active_instance.will_persist():
		print("CALLIE_COUNT %s" % JSON.stringify({
			"count": get_tree().get_nodes_in_group("callie").size(), "skipped_duplicate": true,
		}))
		return

	var half_w: float = FORT_WIDTH * 0.5
	# OUTSIDE the right wall, matching every other prop in this file
	# (LanternVisual, FireflyJarVisual, the walkable cushions in
	# _build_cushions()): the fort itself is a fully enclosed shell (4 solid
	# walls + roof, only the small back doorway gap), so anything placed
	# INSIDE it is invisible to the fixed ClearingCameraHint framing and
	# unreachable except through that one narrow gap.
	var cushion_position: Vector3 = FORT_CENTER + Vector3(half_w + 0.5, 0.0, 0.5)

	var mesh := SphereMesh.new()
	mesh.radius = CALLIE_CUSHION_RADIUS
	mesh.height = CALLIE_CUSHION_RADIUS * 2.0 * CALLIE_CUSHION_HEIGHT_SCALE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = CUSHION_BLUSH
	mesh.material = mat

	var cushion := MeshInstance3D.new()
	cushion.name = "CallieCushion"
	cushion.mesh = mesh
	cushion.position = cushion_position + Vector3(0.0, mesh.height * 0.5, 0.0)
	add_child(cushion)

	var callie: Callie = CALLIE_SCENE.instantiate() as Callie
	callie.name = "Callie"
	callie.position = cushion_position + Vector3(0.0, mesh.height, 0.0)
	add_child(callie)


func world_id() -> String:
	return "pillow_fort"


func spawn_points() -> Dictionary:
	var facing_fort: Basis = Basis.looking_at(Vector3.FORWARD, Vector3.UP) # -Z, toward the fort
	return {
		"pip": Transform3D(facing_fort, Vector3(1.5, 0.1, 3.0)),
		"otto": Transform3D(facing_fort, Vector3(-1.5, 0.1, 3.0)),
	}


func objective_ids() -> Array[String]:
	return [] as Array[String] # fort growth stages arrive in Phase 5


func rescue_floor_y() -> float:
	return RESCUE_FLOOR_Y


func _build_clearing() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = CLEARING_SIZE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = CLEARING_COLOR
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "ClearingGround"
	visual.mesh = mesh
	add_child(visual)
	# ROUND 2 (director's note 2, "flat single-color ground kills the
	# diorama"): patchy sage <-> lighter-sage blend on the clearing's main
	# ground (assets/shaders/ground_patches.gdshader). Override on the
	# MeshInstance3D, not the PlaneMesh resource, so it doesn't disturb the
	# `mat`/`mesh.material` StandardMaterial3D wiring above.
	visual.set_surface_override_material(0, _ground_patch_material(CLEARING_COLOR, CLEARING_GROUND_TINT_B))

	var body := StaticBody3D.new()
	body.name = "ClearingGroundBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CLEARING_SIZE.x, 0.2, CLEARING_SIZE.y)
	shape.shape = box
	shape.position = Vector3(0.0, -0.1, 0.0)
	body.add_child(shape)
	add_child(body)


func _build_fort() -> void:
	var fort := Node3D.new()
	fort.name = "Fort"
	add_child(fort)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = FORT_WALL_COLOR

	var half_w: float = FORT_WIDTH * 0.5
	var half_d: float = FORT_DEPTH * 0.5

	# Left / right walls run the full depth.
	_add_fort_box(fort, Vector3(WALL_THICKNESS, FORT_HEIGHT, FORT_DEPTH),
		FORT_CENTER + Vector3(-half_w + WALL_THICKNESS * 0.5, FORT_HEIGHT * 0.5, 0.0), wall_mat)
	_add_fort_box(fort, Vector3(WALL_THICKNESS, FORT_HEIGHT, FORT_DEPTH),
		FORT_CENTER + Vector3(half_w - WALL_THICKNESS * 0.5, FORT_HEIGHT * 0.5, 0.0), wall_mat)

	# Front wall (the spawn side) is solid — the fort's back is what you see arriving.
	_add_fort_box(fort, Vector3(FORT_WIDTH, FORT_HEIGHT, WALL_THICKNESS),
		FORT_CENTER + Vector3(0.0, FORT_HEIGHT * 0.5, half_d - WALL_THICKNESS * 0.5), wall_mat)

	# Back wall has the doorway gap — this is "the fort door" that looks out
	# across the clearing toward the giants.
	var side_seg_width: float = (FORT_WIDTH - DOOR_WIDTH) * 0.5
	var back_z: float = FORT_CENTER.z - half_d + WALL_THICKNESS * 0.5
	_add_fort_box(fort, Vector3(side_seg_width, FORT_HEIGHT, WALL_THICKNESS),
		FORT_CENTER + Vector3(-half_w + side_seg_width * 0.5, FORT_HEIGHT * 0.5, -half_d + WALL_THICKNESS * 0.5), wall_mat)
	_add_fort_box(fort, Vector3(side_seg_width, FORT_HEIGHT, WALL_THICKNESS),
		FORT_CENTER + Vector3(half_w - side_seg_width * 0.5, FORT_HEIGHT * 0.5, -half_d + WALL_THICKNESS * 0.5), wall_mat)

	# Roof.
	_add_fort_box(fort, Vector3(FORT_WIDTH, WALL_THICKNESS, FORT_DEPTH),
		FORT_CENTER + Vector3(0.0, FORT_HEIGHT, 0.0), wall_mat)

	# Warm interior glow.
	var interior_light := OmniLight3D.new()
	interior_light.name = "InteriorGlow"
	interior_light.light_color = FORT_GLOW_COLOR
	interior_light.light_energy = 1.5
	interior_light.omni_range = 5.0
	interior_light.position = FORT_CENTER + Vector3(0.0, FORT_HEIGHT * 0.6, 0.0)
	fort.add_child(interior_light)

	# Porch lantern just outside the back doorway. LanternVisual is the
	# ground-anchored container ModelSlot needs (D10): it and the grey-box
	# LanternPost mesh are the only two children, so a GLB swap hides just
	# the post, never anything else in the fort.
	var lantern_ground: Vector3 = FORT_CENTER + Vector3(half_w + 0.8, 0.0, -half_d - 0.6)
	var lantern_visual := Node3D.new()
	lantern_visual.name = "LanternVisual"
	lantern_visual.position = lantern_ground
	fort.add_child(lantern_visual)

	var lantern_post := MeshInstance3D.new()
	lantern_post.name = "LanternPost"
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.06
	post_mesh.bottom_radius = 0.06
	post_mesh.height = 1.4
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = FENCE_POST_COLOR
	post_mesh.material = post_mat
	lantern_post.mesh = post_mesh
	lantern_post.position = Vector3(0.0, post_mesh.height * 0.5, 0.0) # rests on lantern_visual's ground
	lantern_visual.add_child(lantern_post)

	var lantern_slot := ModelSlot.new()
	lantern_slot.name = "LanternModelSlot"
	lantern_slot.model_id = "lantern"
	lantern_slot.target_height = 0.5 # ART_BIBLE scale rules: lantern 0.5
	lantern_visual.add_child(lantern_slot)

	var lantern_light := OmniLight3D.new()
	lantern_light.name = "LanternGlow"
	lantern_light.light_color = FORT_GLOW_COLOR
	lantern_light.light_energy = 1.2
	lantern_light.omni_range = 4.0
	lantern_light.position = FORT_CENTER + Vector3(half_w + 0.8, 1.5, -half_d - 0.6)
	fort.add_child(lantern_light)


## D22 graphics-v2 ROUND 2, assets/shaders/ground_patches.gdshader (director's
## note 2): builds a ShaderMaterial pre-loaded with a world's near-neighbor
## tint pair.
func _ground_patch_material(tint_a: Color, tint_b: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ground_patches.gdshader") as Shader
	mat.set_shader_parameter("tint_a", tint_a)
	mat.set_shader_parameter("tint_b", tint_b)
	return mat


func _add_fort_box(parent: Node3D, size: Vector3, box_position: Vector3, mat: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = box_position
	parent.add_child(visual)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = box_position
	body.add_child(shape)
	parent.add_child(body)


func _build_cushions() -> void:
	# Explicit (not randf()) scale jitter, both within ART_BIBLE's cushion
	# 0.4 m baseline +/-15%, so screenshot/harness receipts stay
	# deterministic run to run.
	_add_cushion(Vector3(3.5, 0.0, -1.0), 1.1, CUSHION_BLUSH, 1.08)
	_add_cushion(Vector3(-3.2, 0.0, -3.5), 0.9, CUSHION_DUSK_BLUE, 0.93)


## D22 / recipes "Character rendering": the cushions are the fort's own
## soft-toy plush objects (flat-color spheres before this pass), so they're
## the in-territory demo for assets/shaders/plush_character.gdshader --
## see graphics-v2-VERIFY.md for the one-line instructions to apply the
## same shader to Callie/players (out of this agent's territory to wire
## directly).
func _add_cushion(cushion_position: Vector3, radius: float, color: Color, scale_jitter: float = 1.0) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.2 # squashed
	var mat := load("res://core/env/plush_material.tres").duplicate() as ShaderMaterial
	mat.set_shader_parameter("albedo_color", color)
	mesh.material = mat

	# CushionAnchor is the ground-anchored container ModelSlot needs (D10):
	# it and the grey-box sphere mesh are the only two children, so a GLB
	# swap hides just this cushion's own primitive.
	var anchor := Node3D.new()
	anchor.name = "Cushion"
	anchor.position = cushion_position + Vector3(0.0, radius * 0.55, 0.0)
	add_child(anchor)

	var visual := MeshInstance3D.new()
	visual.name = "CushionMesh"
	visual.mesh = mesh
	anchor.add_child(visual)

	var slot := ModelSlot.new()
	slot.name = "CushionModelSlot"
	slot.model_id = "cushion"
	slot.target_height = 0.4 * scale_jitter # ART_BIBLE scale rules: cushion 0.4, varied per-instance
	anchor.add_child(slot)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	shape.shape = sphere_shape
	shape.position = anchor.position
	shape.scale = Vector3(1.0, mesh.height / (radius * 2.0), 1.0)
	body.add_child(shape)
	add_child(body)


func _build_fence() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = FENCE_POST_COLOR
	for i: int in range(FENCE_POST_COUNT):
		var angle: float = TAU * float(i) / float(FENCE_POST_COUNT)
		var post_position: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * FENCE_POST_RADIUS
		_add_fence_post(post_position, mat)


func _add_fence_post(post_position: Vector3, mat: StandardMaterial3D) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.08
	mesh.bottom_radius = 0.1
	mesh.height = FENCE_POST_HEIGHT
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "FencePost"
	visual.mesh = mesh
	visual.position = post_position + Vector3(0.0, FENCE_POST_HEIGHT * 0.5, 0.0)
	add_child(visual)


## D22 graphics-v2: cast_shadow OFF, same fix/reasoning as marmalade.gd's
## CatSilhouette — a distant "just shape, unreachable" backdrop prop
## shouldn't be able to shadow the gameplay clearing now that the moon key
## light (core/env/ambience.gd) actually casts shadows.
func _build_bear_silhouette() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = BEAR_SILHOUETTE_RADIUS
	mesh.height = BEAR_SILHOUETTE_RADIUS * 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BEAR_SILHOUETTE_COLOR
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "BrambleSkylineSilhouette"
	visual.mesh = mesh
	visual.position = BEAR_SILHOUETTE_POSITION
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual) # visual only — unreachable, just shape (per brief)


func _build_camera_hint() -> void:
	var hint := CameraHint.new()
	hint.name = "ClearingCameraHint"
	hint.priority = 0
	hint.yaw_degrees = 0.0 # facing -Z: the fort door and the bear skyline beyond it
	hint.blend_time = 1.0

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CLEARING_SIZE.x, 10.0, CLEARING_SIZE.y)
	shape.shape = box
	shape.position = Vector3(0.0, 3.0, 0.0)
	hint.add_child(shape)
	# Detection semantics (monitoring/layers) are the camera rig's contract to
	# define, not this world's — left at Area3D defaults so whatever query
	# core/camera/camera_rig.gd uses finds this volume.
	add_child(hint)


func _build_bramble_door() -> void:
	# One door per giant, each tinted to its world's palette so a pre-reader
	# can tell them apart at a glance. Bramble: umber, straight out the back
	# (toward the silhouette on the skyline). Marmalade: east. Wisp: west.
	var half_d: float = FORT_DEPTH * 0.5
	_add_world_door("BrambleDoor", "bramble",
		FORT_CENTER + Vector3(0.0, 0.0, -half_d - 1.2), 0.0, Color("8A6552"))
	_add_world_door("MarmaladeDoor", "marmalade",
		Vector3(9.5, 0.0, -2.0), 90.0, Color("D98E4A"))
	_add_world_door("WispDoor", "wisp",
		Vector3(-9.5, 0.0, -2.0), -90.0, Color("C9D4E4"))


func _add_world_door(door_name: String, target: String, door_position: Vector3, yaw_degrees: float, tint: Color) -> void:
	var door := WorldDoor.new()
	door.name = door_name
	door.target_world = target
	door.frame_color = tint
	door.position = door_position
	door.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	add_child(door)
	door.exit_requested.connect(func() -> void:
		exit_requested_to.emit(target)
		exit_requested.emit()
	)


