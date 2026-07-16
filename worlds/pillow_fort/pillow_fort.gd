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
	super._ready()


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

	# Porch lantern just outside the back doorway.
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
	lantern_post.position = FORT_CENTER + Vector3(half_w + 0.8, 0.7, -half_d - 0.6)
	fort.add_child(lantern_post)

	var lantern_light := OmniLight3D.new()
	lantern_light.name = "LanternGlow"
	lantern_light.light_color = FORT_GLOW_COLOR
	lantern_light.light_energy = 1.2
	lantern_light.omni_range = 4.0
	lantern_light.position = lantern_post.position + Vector3(0.0, 0.8, 0.0)
	fort.add_child(lantern_light)


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
	_add_cushion(Vector3(3.5, 0.0, -1.0), 1.1, CUSHION_BLUSH)
	_add_cushion(Vector3(-3.2, 0.0, -3.5), 0.9, CUSHION_DUSK_BLUE)


func _add_cushion(cushion_position: Vector3, radius: float, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.2 # squashed
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "Cushion"
	visual.mesh = mesh
	visual.position = cushion_position + Vector3(0.0, radius * 0.55, 0.0)
	add_child(visual)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	shape.shape = sphere_shape
	shape.position = visual.position
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
	var door := WorldDoor.new()
	door.name = "BrambleDoor"
	door.target_world = "bramble"
	var half_d: float = FORT_DEPTH * 0.5
	door.position = FORT_CENTER + Vector3(0.0, 0.0, -half_d - 1.2)
	add_child(door)
	door.exit_requested.connect(_on_bramble_door_exit_requested)


func _on_bramble_door_exit_requested() -> void:
	exit_requested.emit()
