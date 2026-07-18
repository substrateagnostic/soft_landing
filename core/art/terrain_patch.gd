class_name TerrainPatch
extends MeshInstance3D
## TerrainPatch — D27 terrain v1 (producer playtest: "we'll want more
## dynamic terrain — not just flat objects at various angles... even
## Mario 64 had its polygons"). A gently rolling heightfield ground slab
## that drops in where a flat box slab used to be:
##
##   - THIS node is the MeshInstance3D (so `get_node("Meadow")`-style
##     surface-override wiring in the worlds keeps working verbatim).
##   - Heights come from seeded FastNoiseLite fBm — fully deterministic
##     for a given seed (receipts/screenshots stay stable run to run).
##   - The border eases to EXACTLY y=0 over edge_margin meters, so the
##     patch stays flush with moat rings / neighboring plates.
##   - flat_discs (x, z, radius in world/local XZ, shared frame since the
##     patch sits at the world origin in every current caller) pin the
##     ground flat around authored gameplay anchors — trailheads, doors,
##     spawns — with a feathered blend outward.
##   - Collision is a real HeightMapShape3D child (exact, Jolt-supported),
##     built from THE SAME height function — visual and physics can't
##     drift. Layer 1, matching every _add_ground_slab.
##
## Convention: setup() BEFORE add_child (this repo's established pattern);
## _ready() builds mesh + collision.

const DEFAULT_RESOLUTION: int = 72

var _size: Vector2 = Vector2(40.0, 40.0)
var _amplitude: float = 0.45
var _wavelength: float = 18.0
var _seed: int = 7
var _flat_discs: Array[Vector3] = [] # (x, z, radius); feather = radius * 0.7 beyond
var _edge_margin: float = 8.0
var _resolution: int = DEFAULT_RESOLUTION
var _skirt_depth: float = 2.5

var _noise: FastNoiseLite = null


func setup(
	size: Vector2, amplitude: float, wavelength: float, noise_seed: int,
	flat_discs: Array[Vector3] = [], edge_margin: float = 8.0,
	resolution: int = DEFAULT_RESOLUTION, skirt_depth: float = 2.5
) -> void:
	_size = size
	_amplitude = amplitude
	_wavelength = wavelength
	_seed = noise_seed
	_flat_discs = flat_discs
	_edge_margin = edge_margin
	_resolution = resolution
	_skirt_depth = skirt_depth


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = _seed
	_noise.frequency = 1.0 / maxf(_wavelength, 0.001)
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3
	_noise.fractal_gain = 0.45

	_build_mesh()
	_build_collision()
	print("TERRAIN_PATCH %s" % JSON.stringify({
		"name": String(name), "size": [_size.x, _size.y],
		"amplitude": _amplitude, "seed": _seed, "res": _resolution,
	}))


## sample_height — the single source of truth for both mesh and collision
## (and for any future prop-snapping pass). Local-space XZ.
func sample_height(x: float, z: float) -> float:
	var h: float = _noise.get_noise_2d(x, z) * _amplitude

	var half: Vector2 = _size * 0.5
	var edge_x: float = clampf((half.x - absf(x)) / _edge_margin, 0.0, 1.0)
	var edge_z: float = clampf((half.y - absf(z)) / _edge_margin, 0.0, 1.0)
	h *= smoothstep(0.0, 1.0, edge_x) * smoothstep(0.0, 1.0, edge_z)

	for disc: Vector3 in _flat_discs:
		var dist: float = Vector2(x - disc.x, z - disc.y).length()
		var feather: float = disc.z * 0.7
		h *= smoothstep(disc.z, disc.z + feather, dist)
	return h


func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: Vector2 = _size * 0.5
	var step_x: float = _size.x / float(_resolution - 1)
	var step_z: float = _size.y / float(_resolution - 1)

	for iz: int in range(_resolution - 1):
		for ix: int in range(_resolution - 1):
			var x0: float = -half.x + ix * step_x
			var z0: float = -half.y + iz * step_z
			var x1: float = x0 + step_x
			var z1: float = z0 + step_z
			var p00 := Vector3(x0, sample_height(x0, z0), z0)
			var p10 := Vector3(x1, sample_height(x1, z0), z0)
			var p01 := Vector3(x0, sample_height(x0, z1), z1)
			var p11 := Vector3(x1, sample_height(x1, z1), z1)
			# Two CCW-from-above triangles per cell.
			st.add_vertex(p00)
			st.add_vertex(p01)
			st.add_vertex(p10)
			st.add_vertex(p10)
			st.add_vertex(p01)
			st.add_vertex(p11)

	# SKIRT — the flat boxes this class replaces had visible SIDE faces;
	# a bare heightfield sheet viewed edge-on shows the void between its
	# rim and the moat below (caught live on wisp's establishing shot:
	# "floating slab over a black gap"). Perimeter quads drop skirt_depth
	# below the border verts, both windings so every side reads solid
	# from any angle without per-side case analysis.
	if _skirt_depth > 0.0:
		_add_skirt(st, half, step_x, step_z)

	st.index()
	st.generate_normals()
	mesh = st.commit()


func _add_skirt(st: SurfaceTool, half: Vector2, step_x: float, step_z: float) -> void:
	var drop := Vector3(0.0, -_skirt_depth, 0.0)
	for i: int in range(_resolution - 1):
		var x0: float = -half.x + i * step_x
		var x1: float = x0 + step_x
		var z0: float = -half.y + i * step_z
		var z1: float = z0 + step_z
		var edges: Array = [
			[Vector3(x0, sample_height(x0, -half.y), -half.y), Vector3(x1, sample_height(x1, -half.y), -half.y)],
			[Vector3(x1, sample_height(x1, half.y), half.y), Vector3(x0, sample_height(x0, half.y), half.y)],
			[Vector3(-half.x, sample_height(-half.x, z1), z1), Vector3(-half.x, sample_height(-half.x, z0), z0)],
			[Vector3(half.x, sample_height(half.x, z0), z0), Vector3(half.x, sample_height(half.x, z1), z1)],
		]
		for edge: Array in edges:
			var a: Vector3 = edge[0]
			var b: Vector3 = edge[1]
			for winding: Array in [[a, b, a + drop, b, b + drop, a + drop], [b, a, a + drop, b, a + drop, b + drop]]:
				for v: Vector3 in winding:
					st.add_vertex(v)


func _build_collision() -> void:
	var heights := PackedFloat32Array()
	heights.resize(_resolution * _resolution)
	var half: Vector2 = _size * 0.5
	var step_x: float = _size.x / float(_resolution - 1)
	var step_z: float = _size.y / float(_resolution - 1)
	for iz: int in range(_resolution):
		for ix: int in range(_resolution):
			heights[iz * _resolution + ix] = sample_height(-half.x + ix * step_x, -half.y + iz * step_z)

	var shape := HeightMapShape3D.new()
	shape.map_width = _resolution
	shape.map_depth = _resolution
	shape.map_data = heights

	var collision := CollisionShape3D.new()
	collision.name = "TerrainShape"
	collision.shape = shape
	# HeightMapShape3D cells are 1 unit apart — scale to the real footprint.
	collision.scale = Vector3(step_x, 1.0, step_z)

	var body := StaticBody3D.new()
	body.name = String(name) + "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_child(collision)
	add_child(body)
