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
##
## D26 disguise pass (director verdict on evidence/stills/m3_mountain/
## v4_wide_disguised/shot_150.png: "the disguise fails" — teddy-orange fur,
## soap-bubble clouds, an exposed sitting silhouette): two additions on top
## of the original registry above.
##   1. ROCK-TINT (_rock_tint_bear/_restore_bear_fur): while unrevealed, every
##      surface of the BearRig's skinned mesh gets a StandardMaterial3D
##      override that keeps the rig's own albedo_texture but MULTIPLIES it by
##      a desaturated grey-green-umber (ROCK_TINT_COLOR) instead of replacing
##      it outright (per the brief: "multiplies... rather than replacing"),
##      following the exact surface-walk core/art/rigged_model_slot.gd's own
##      _apply_plush_material already uses. Because ROCK_TINT_COLOR's own red
##      channel sits well below its green/blue, the multiply doesn't just
##      darken the warm-orange fur texture — it suppresses red harder than
##      green/blue and drags the hue itself toward moss/stone rather than
##      leaving a dim orange. Restored (override cleared -> original texture/
##      color shows again) inside reveal()'s existing debris-fall timer, so
##      the true warm fur comes back exactly when the falling stones/pines
##      already give the eye something else to look at.
##   2. CLOUD BANK rebuild (_build_cloud_ring): the old ring was 8 small,
##      uniformly-spaced, fast-uniform-rotating balls orbiting the SHELL
##      ANCHOR at a radius (22m) chosen specifically to clear the head, which
##      is exactly why they read as a loose ring of soap bubbles near the
##      shoulders instead of a cloud bank hiding the head/face. Rebuilt to
##      orbit the HEAD itself (bramble.gd now passes BEAR_HEAD_WORLD_CENTER,
##      not the shell anchor) at a radius that overlaps the head's own
##      12m-radius collision sphere, with extra density banked toward his
##      face direction (world +X — bramble.gd's own BEAR_SHELL_YAW_DEGREES
##      header note) since that's the one gap the M3 verify pass named
##      explicitly. Each cloud now drifts at its OWN randomized rate/phase
##      (no shared pivot rotation) so the bank reads as weather, not a
##      carousel.

const COLOR_STONE: Color = Color(0.55, 0.58, 0.52)
const COLOR_SNOW: Color = Color("F5F2E8")
const COLOR_PINE: Color = Color("6E8F6A")
# Milk-white at high alpha (was pure white at 0.55 — read as glassy soap
# bubbles, not cloud), per the disguise brief's #2.
const COLOR_CLOUD: Color = Color(0.961, 0.949, 0.910, 0.85)

const STONE_RADIUS: float = 0.55
const PINE_RADIUS: float = 0.5
const PINE_HEIGHT: float = 2.2
const SNOW_CAP_RADIUS: float = 2.0

# Ring now orbits the HEAD (bramble.gd passes BEAR_HEAD_WORLD_CENTER as
# cloud_ring_center in setup(), not the old shell-anchor point) so a small
# orbit radius means "wreathing the head," not "somewhere near the shoulders."
const CLOUD_COUNT: int = 16 # main wreath positions around the head
const CLOUD_FACE_EXTRA: int = 6 # additional density banked toward the face
const CLOUD_RADIUS_MIN: float = 3.4
const CLOUD_RADIUS_MAX: float = 5.6
# Head collision sphere radius is 12m (bramble.gd BEAR_HEAD_SPHERE_RADIUS) —
# an 8-13m orbit means cloud VOLUMES (radius ~3.4-5.6 themselves) overlap the
# head surface directly instead of floating clear of it, so the head visually
# dissolves into the bank instead of poking up above a ring around it.
const CLOUD_ORBIT_RADIUS_MIN: float = 8.0
const CLOUD_ORBIT_RADIUS_MAX: float = 13.0
const CLOUD_HEIGHT_MIN: float = -6.0 # relative to cloud_ring_center (the head center)
const CLOUD_HEIGHT_MAX: float = 9.0 # reaches well above the head's top (radius 12 -> +12 alone)
# His face points world +X (bramble.gd BEAR_SHELL_YAW_DEGREES header note,
# verified by still) — the one named gap in mountain-m3-VERIFY.md's verdict.
const CLOUD_FACE_DIRECTION: Vector3 = Vector3(1.0, 0.0, 0.0)
const CLOUD_FACE_ARC_DEGREES: float = 130.0
const CLOUD_DRIFT_MIN_DEG_PER_SEC: float = 1.2
const CLOUD_DRIFT_MAX_DEG_PER_SEC: float = 4.0

const CLOUD_BLOW_DURATION: float = 1.5
const CLOUD_BLOW_OUTWARD: float = 14.0
const PROP_FALL_DURATION: float = 1.2
const PROP_FALL_DROP: float = 6.0
const PROP_FALL_TUMBLE_DEGREES: float = 220.0
const PROP_FALL_STAGGER_WINDOW: float = 2.5

# D26 rock-tint: grey-green-umber, between COLOR_MEADOW (#7C9082) and
# COLOR_FUR_DARK (#6E4F3E) in luminance, but with red pulled down HARD
# relative to green/blue — a plain per-channel multiply can only darken, it
# can't add missing channels, so the only way to drag an orange fur texture's
# HUE toward moss/stone (not just dim it) is to suppress the channel the
# texture is strongest in (red) more than the others.
const ROCK_TINT_COLOR: Color = Color(0.30, 0.44, 0.37)

var _world: Node3D = null
var _world_id: String = ""
var _cloud_ring_center: Vector3 = Vector3.ZERO
var _ascent_waypoints: Array[Vector3] = []

var _props: Array[Node3D] = [] # stones/pines/snow — everything but clouds
var _cloud_pivot: Node3D = null
var _clouds: Array[MeshInstance3D] = []
var _cloud_data: Array[Dictionary] = [] # parallel to _clouds: {angle, radius, height, drift}
var _revealed: bool = false

var _rig_overrides: Array[Dictionary] = [] # {mesh: MeshInstance3D, surface: int} — for fur restore


## setup — called by bramble.gd BEFORE add_child (established convention in
## this codebase; see rollover_sequence.gd's own setup() note about why).
## world: the Bramble world node itself (BearShellAnchor/BearRig lookup for
## the rock-tint, same explicit-reference convention rollover_sequence.gd
## uses rather than get_parent()). world_id: the GameState.
## is_world_completed() key. cloud_ring_center: world-space point (now the
## HEAD center, not the shell anchor — see header) the cloud bank wreathes.
## ascent_waypoints: the ASCENT_* chain (base..summit) — stones/pines scatter
## near these; the last entry is treated as the summit for the snow caps.
func setup(world: Node3D, world_id: String, cloud_ring_center: Vector3, ascent_waypoints: Array[Vector3]) -> void:
	_world = world
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
	_rock_tint_bear()


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


## Full wreath (CLOUD_COUNT spread evenly around the head) plus a
## face-biased extra batch (CLOUD_FACE_EXTRA, angles drawn from a narrow arc
## centered on CLOUD_FACE_DIRECTION) so the one named disguise gap — the
## exposed face on the east/+X side (mountain-m3-VERIFY.md's verdict) — gets
## denser coverage than the rest of the ring, not just equal coverage.
func _build_cloud_ring() -> void:
	_cloud_pivot = Node3D.new()
	_cloud_pivot.name = "CloudRingPivot"
	_cloud_pivot.position = _cloud_ring_center
	add_child(_cloud_pivot)

	var face_angle: float = atan2(CLOUD_FACE_DIRECTION.x, CLOUD_FACE_DIRECTION.z)
	var face_arc: float = deg_to_rad(CLOUD_FACE_ARC_DEGREES)

	for i: int in range(CLOUD_COUNT):
		_spawn_cloud(TAU * float(i) / float(CLOUD_COUNT) + randf_range(-0.12, 0.12))
	for _i: int in range(CLOUD_FACE_EXTRA):
		_spawn_cloud(face_angle + randf_range(-face_arc * 0.5, face_arc * 0.5))

	set_physics_process(true)


func _spawn_cloud(angle: float) -> void:
	var index: int = _clouds.size()
	var r: float = randf_range(CLOUD_RADIUS_MIN, CLOUD_RADIUS_MAX)
	var cloud := MeshInstance3D.new()
	cloud.name = "Cloud%d" % index
	cloud.mesh = _make_sphere_mesh(r)
	var mat := _make_material(COLOR_CLOUD)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud.set_surface_override_material(0, mat)
	_cloud_pivot.add_child(cloud)
	_clouds.append(cloud)
	_cloud_data.append({
		"angle": angle,
		"radius": randf_range(CLOUD_ORBIT_RADIUS_MIN, CLOUD_ORBIT_RADIUS_MAX),
		"height": randf_range(CLOUD_HEIGHT_MIN, CLOUD_HEIGHT_MAX),
		# +/- direction so the bank doesn't rotate as one rigid disc (the
		# "carousel" the brief calls out) — each cloud drifts its own way.
		"drift": randf_range(CLOUD_DRIFT_MIN_DEG_PER_SEC, CLOUD_DRIFT_MAX_DEG_PER_SEC) * (1.0 if randf() > 0.5 else -1.0),
	})
	_reposition_cloud(index)


func _reposition_cloud(index: int) -> void:
	var data: Dictionary = _cloud_data[index]
	var angle: float = float(data["angle"])
	var r: float = float(data["radius"])
	_clouds[index].position = Vector3(sin(angle) * r, float(data["height"]), cos(angle) * r)


func _physics_process(delta: float) -> void:
	if _revealed:
		return
	for i: int in range(_cloud_data.size()):
		if not is_instance_valid(_clouds[i]):
			continue
		_cloud_data[i]["angle"] = float(_cloud_data[i]["angle"]) + deg_to_rad(float(_cloud_data[i]["drift"])) * delta
		_reposition_cloud(i)


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
	# Fur restore fires in the SAME beat as the debris starting to fall — the
	# falling stones/pines are the "dust/debris moment" the brief asks to
	# cover the material swap with, so the two are deliberately bound to one
	# timer rather than each getting their own independent delay.
	timer.timeout.connect(_restore_bear_fur)
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
# D26 rock-tint: while disguised, the rig reads as mossy stone; the reveal
# restores his true warm fur. Same MeshInstance3D surface-walk core/art/
# rigged_model_slot.gd's _apply_plush_material already uses to reach every
# surface of a skinned rig, but overriding with a MULTIPLY tint (albedo_
# texture carried through unchanged, only albedo_color changes) instead of a
# full material replacement — see header comment for why ROCK_TINT_COLOR's
# low red channel is what actually shifts the hue, not just the darkness.
# ---------------------------------------------------------------------------

func _find_bear_rig() -> Node3D:
	if _world == null:
		return null
	var shell: Node3D = _world.get_node_or_null("BearShellAnchor") as Node3D
	if shell == null:
		return null
	return shell.get_node_or_null("BearRig") as Node3D


func _rock_tint_bear() -> void:
	var rig: Node3D = _find_bear_rig()
	if rig == null:
		return # static ModelSlot fallback (no rigged giant on disk yet) — nothing to tint
	_rig_overrides.clear()
	var stack: Array[Node] = [rig]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi: MeshInstance3D = node
			if mi.mesh != null:
				for surface: int in range(mi.mesh.get_surface_count()):
					var original: StandardMaterial3D = mi.mesh.surface_get_material(surface) as StandardMaterial3D
					var tint := StandardMaterial3D.new()
					if original != null:
						tint.albedo_texture = original.albedo_texture
					tint.albedo_color = ROCK_TINT_COLOR
					mi.set_surface_override_material(surface, tint)
					_rig_overrides.append({"mesh": mi, "surface": surface})
		for child: Node in node.get_children():
			stack.append(child)
	print("DISGUISE %s" % JSON.stringify({"event": "rock_tinted", "surfaces": _rig_overrides.size()}))


## Clears every override this pass added — the mesh's OWN original material
## (texture + true warm-fur albedo_color) shows again, no re-authoring of it
## needed here. Idempotent (an already-cleared list is just a no-op loop).
func _restore_bear_fur() -> void:
	for entry: Dictionary in _rig_overrides:
		var mi: MeshInstance3D = entry["mesh"] as MeshInstance3D
		if is_instance_valid(mi):
			mi.set_surface_override_material(int(entry["surface"]), null)
	_rig_overrides.clear()
	print("DISGUISE %s" % JSON.stringify({"event": "fur_restored"}))


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
