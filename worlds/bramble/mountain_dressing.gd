class_name MountainDressing
extends Node3D
## MountainDressing — D25 "dressed as terrain" (docs/DECISIONS.md D25): the
## disguise props that make the rescaled bear massif (worlds/bramble/
## bramble.gd's BearShellAnchor + its ASCENT_* switchback path) read as a
## mountain, not a bear, to a first-time child player. A single registry
## (built once, never rebuilt) with one reveal() API the 10/10 finale calls
## (worlds/bramble/rollover_sequence.gd): the cloud ring blows outward and
## fades first (~1.5s), then every remaining prop (stones, pines, snow caps)
## detaches and falls — local down + a slight tumble + a fade — staggered
## randomly across ~2.5s more, then frees.
##
## The ascent path itself (the dirt-tinted ramps/ledges bramble.gd builds in
## _build_ascent()) is NOT part of this registry on purpose: those are real,
## permanent collision the player is standing on mid-cutscene (everyone is
## already bubble-lifted off the bear before reveal() ever fires, per
## rollover_sequence.gd, but the path itself stays — a mountain that just
## woke up keeps its ledges; only the loose disguise dressing falls away).
##
## Positions come from setup() (bramble.gd's own D25 constants), not
## re-guessed here, so a future retune of the massif doesn't silently desync
## the dressing. On a revisit AFTER the world is already complete
## (GameState.is_world_completed), _ready() builds nothing at all — "the
## bear stays revealed forever" needs no teardown when there was never
## anything built to tear down.

const COLOR_STONE: Color = Color(0.55, 0.58, 0.52)
const COLOR_SNOW: Color = Color("F5F2E8")
const COLOR_PINE: Color = Color("6E8F6A")
const COLOR_CLOUD: Color = Color(1.0, 1.0, 1.0, 0.55)

const STONE_RADIUS: float = 0.55
const PINE_RADIUS: float = 0.5
const PINE_HEIGHT: float = 2.2
const SNOW_CAP_RADIUS: float = 2.0

const CLOUD_COUNT: int = 8
const CLOUD_RADIUS: float = 3.0
# v2 (still-corrected, evidence/stills/m3_mountain/v3_east/shot_150.png): 16m
# put clouds visibly overlapping his face/cheek from a close side angle —
# his head reads bigger than the collision-sphere guess it was sized
# against. 22m clears it with margin.
const CLOUD_ORBIT_RADIUS: float = 22.0
const CLOUD_DRIFT_DEGREES_PER_SEC: float = 2.0 # slow — "weather," not a carousel

const CLOUD_BLOW_DURATION: float = 1.5
const CLOUD_BLOW_OUTWARD: float = 14.0
const PROP_FALL_DURATION: float = 1.2
const PROP_FALL_DROP: float = 6.0
const PROP_FALL_TUMBLE_DEGREES: float = 220.0
const PROP_FALL_STAGGER_WINDOW: float = 2.5

var _world_id: String = ""
var _cloud_ring_center: Vector3 = Vector3.ZERO
var _ascent_waypoints: Array[Vector3] = []

var _props: Array[Node3D] = [] # stones/pines/snow — everything but clouds
var _cloud_pivot: Node3D = null
var _clouds: Array[MeshInstance3D] = []
var _revealed: bool = false


## setup — called by bramble.gd BEFORE add_child (established convention in
## this codebase; see rollover_sequence.gd's own setup() note about why).
## world_id: the GameState.is_world_completed() key. cloud_ring_center:
## world-space point at shoulder height the cloud ring orbits. ascent_
## waypoints: the ASCENT_* chain (base..summit) — stones/pines scatter near
## these; the last entry is treated as the summit for the snow caps.
func setup(world_id: String, cloud_ring_center: Vector3, ascent_waypoints: Array[Vector3]) -> void:
	_world_id = world_id
	_cloud_ring_center = cloud_ring_center
	_ascent_waypoints = ascent_waypoints


func _ready() -> void:
	if GameState.is_world_completed(_world_id):
		return # D25 persistence: already revealed in a prior session
	_build_stones()
	_build_pines()
	_build_snow_caps()
	_build_cloud_ring()


# ---------------------------------------------------------------------------
# Build (visual-only walk-through, the fort convention — zero route
# interference with the ascent's own ramps/ledges)
# ---------------------------------------------------------------------------

func _build_stones() -> void:
	for wp: Vector3 in _ascent_waypoints:
		var offset: Vector3 = Vector3(randf_range(-2.5, 2.5), 0.25, randf_range(-2.5, 2.5))
		_spawn_prop(_make_sphere_material(STONE_RADIUS, COLOR_STONE), _make_sphere_mesh(STONE_RADIUS), wp + offset)


func _build_pines() -> void:
	# On his flanks, at alternating waypoints along the climb — sparse, not a
	# forest (the ascent still has to read clearly).
	for i: int in range(_ascent_waypoints.size() - 1): # skip the summit itself (snow caps own that)
		if i % 2 == 0:
			continue
		var wp: Vector3 = _ascent_waypoints[i]
		var offset: Vector3 = Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = PINE_RADIUS
		mesh.height = PINE_HEIGHT
		_spawn_prop(_make_material(COLOR_PINE), mesh, wp + offset + Vector3(0.0, PINE_HEIGHT * 0.5, 0.0))


func _build_snow_caps() -> void:
	if _ascent_waypoints.is_empty():
		return
	var summit: Vector3 = _ascent_waypoints[_ascent_waypoints.size() - 1]
	for i: int in range(4):
		var angle: float = TAU * float(i) / 4.0
		var r: float = SNOW_CAP_RADIUS * randf_range(0.7, 1.0)
		var offset: Vector3 = Vector3(cos(angle) * 3.5, -0.8, sin(angle) * 3.5)
		_spawn_prop(_make_sphere_material(r, COLOR_SNOW), _make_sphere_mesh(r), summit + offset)


func _spawn_prop(mat: StandardMaterial3D, mesh: Mesh, world_pos: Vector3) -> void:
	var visual := MeshInstance3D.new()
	visual.name = "DressingProp"
	visual.mesh = mesh
	visual.set_surface_override_material(0, mat)
	visual.position = world_pos
	add_child(visual)
	_props.append(visual)


func _build_cloud_ring() -> void:
	_cloud_pivot = Node3D.new()
	_cloud_pivot.name = "CloudRingPivot"
	_cloud_pivot.position = _cloud_ring_center
	add_child(_cloud_pivot)

	for i: int in range(CLOUD_COUNT):
		var angle: float = TAU * float(i) / float(CLOUD_COUNT)
		var r: float = CLOUD_RADIUS * randf_range(0.8, 1.2)
		var cloud := MeshInstance3D.new()
		cloud.name = "Cloud%d" % i
		cloud.mesh = _make_sphere_mesh(r)
		var mat := _make_material(COLOR_CLOUD)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cloud.set_surface_override_material(0, mat)
		cloud.position = Vector3(cos(angle) * CLOUD_ORBIT_RADIUS, randf_range(-1.5, 1.5), sin(angle) * CLOUD_ORBIT_RADIUS)
		_cloud_pivot.add_child(cloud)
		_clouds.append(cloud)

	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _cloud_pivot == null or _revealed:
		return
	_cloud_pivot.rotate_y(deg_to_rad(CLOUD_DRIFT_DEGREES_PER_SEC) * delta)


# ---------------------------------------------------------------------------
# reveal() — the 10/10 finale (rollover_sequence.gd calls this once, timed so
# the debris-fall portion lands during the "wake" keystone clip).
# ---------------------------------------------------------------------------

func reveal() -> void:
	if _revealed:
		return
	_revealed = true
	print("DRESSING %s" % JSON.stringify({"phase": "reveal_start", "clouds": _clouds.size(), "props": _props.size()}))
	_blow_clouds()
	var timer: SceneTreeTimer = get_tree().create_timer(CLOUD_BLOW_DURATION * 0.6)
	timer.timeout.connect(_fall_all_props)


func _blow_clouds() -> void:
	for cloud: MeshInstance3D in _clouds:
		if not is_instance_valid(cloud):
			continue
		var outward: Vector3 = cloud.position.normalized() if cloud.position.length() > 0.01 else Vector3.FORWARD
		var target: Vector3 = cloud.position + outward * CLOUD_BLOW_OUTWARD + Vector3(0.0, 3.0, 0.0)
		var mat: StandardMaterial3D = cloud.get_surface_override_material(0) as StandardMaterial3D
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(cloud, "position", target, CLOUD_BLOW_DURATION)
		if mat != null:
			tween.tween_property(mat, "albedo_color:a", 0.0, CLOUD_BLOW_DURATION)
		tween.chain().tween_callback(cloud.queue_free)
	print("DRESSING %s" % JSON.stringify({"phase": "clouds_blown"}))


func _fall_all_props() -> void:
	for prop: Node3D in _props:
		if not is_instance_valid(prop):
			continue
		var delay: float = randf_range(0.0, PROP_FALL_STAGGER_WINDOW)
		var timer: SceneTreeTimer = get_tree().create_timer(delay)
		timer.timeout.connect(_fall_one_prop.bind(prop))
	print("DRESSING %s" % JSON.stringify({"phase": "debris_falling"}))


func _fall_one_prop(prop: Node3D) -> void:
	if not is_instance_valid(prop):
		return
	var mesh_instance: MeshInstance3D = prop as MeshInstance3D
	var mat: StandardMaterial3D = null
	if mesh_instance != null:
		mat = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if mat != null and mat.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(prop, "position:y", prop.position.y - PROP_FALL_DROP, PROP_FALL_DURATION)
	tween.tween_property(prop, "rotation:x", prop.rotation.x + deg_to_rad(PROP_FALL_TUMBLE_DEGREES), PROP_FALL_DURATION)
	tween.tween_property(prop, "rotation:z", prop.rotation.z + deg_to_rad(PROP_FALL_TUMBLE_DEGREES * 0.6), PROP_FALL_DURATION)
	if mat != null:
		tween.tween_property(mat, "albedo_color:a", 0.0, PROP_FALL_DURATION)
	tween.chain().tween_callback(prop.queue_free)


# ---------------------------------------------------------------------------
# Primitive helpers (same "flat StandardMaterial3D, ART_BIBLE.md palette
# only" grey-box convention as the rest of this world — see bramble.gd's own
# _dressing_sphere/_dressing_cone)
# ---------------------------------------------------------------------------

func _make_sphere_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _make_sphere_material(_radius: float, color: Color) -> StandardMaterial3D:
	return _make_material(color)


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
