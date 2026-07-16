class_name GrassField
extends MultiMeshInstance3D
## GrassField — full-geometry wind-swayed grass/reed blades via MultiMesh
## (D22 / recipes "Wind & vegetation"): one draw call per field, 1 solid-
## color triangle per blade (within the recipe's 3-7 tri budget), tinted
## root->tip via assets/shaders/wind_sway.gdshader. Plant a field by adding
## a GrassField to a world, then calling scatter(); no scene file needed
## (matches this codebase's grey-box convention of building visuals in
## code — see worlds/*.gd's mesh helpers).

@export var blade_height: float = 0.22
@export var blade_width: float = 0.13
@export var base_color: Color = Color("7C9082")
@export var tip_color: Color = Color("9DB39A")
@export var sway_strength: float = 0.10
@export var sway_speed: float = 1.0

const TIP_WIDTH_RATIO: float = 0.4 # tip width as a fraction of root width -- blunt, not a needle point


## Scatters `density` blades in an XZ rectangle `field_size` centered on
## `center` (local space), each with a random yaw + small scale jitter.
## `rng_seed` keeps receipts (screenshots, placement checks) deterministic
## run-to-run, matching this codebase's explicit-seed convention elsewhere
## (pillow_fort.gd's cushion jitter comment).
##
## ROUND 2 (director's note 1, "clumped patches instead of uniform
## stubble"): blades are no longer scattered uniformly across the whole
## rectangle -- a handful of clump centers are picked first, then each blade
## is placed near its assigned clump with a center-weighted radius (soft
## edge, not a hard circle), so the field reads as tufts of grass you'd
## actually nap on, not even lawn stubble.
func scatter(center: Vector3, field_size: Vector2, density: int, rng_seed: int) -> void:
	var mesh: ArrayMesh = _build_blade_mesh()
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = load("res://assets/shaders/wind_sway.gdshader") as Shader
	shader_mat.set_shader_parameter("base_color", base_color)
	shader_mat.set_shader_parameter("tip_color", tip_color)
	shader_mat.set_shader_parameter("sway_strength", sway_strength)
	shader_mat.set_shader_parameter("sway_speed", sway_speed)
	mesh.surface_set_material(0, shader_mat)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = density
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # cheap: blades are thin, self-shadowing reads noisy

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var clump_count: int = clampi(int(density / 18.0), 3, 10)
	var clump_radius: float = min(field_size.x, field_size.y) * 0.30
	var clump_centers: Array[Vector2] = []
	for c: int in range(clump_count):
		clump_centers.append(Vector2(
			rng.randf_range(-field_size.x * 0.5, field_size.x * 0.5),
			rng.randf_range(-field_size.y * 0.5, field_size.y * 0.5)
		))

	for i: int in range(density):
		var clump: Vector2 = clump_centers[rng.randi() % clump_count]
		var radius: float = clump_radius * pow(rng.randf(), 1.5) # center-weighted density, soft edge
		var angle: float = rng.randf_range(0.0, TAU)
		var x: float = clampf(clump.x + cos(angle) * radius, -field_size.x * 0.5, field_size.x * 0.5)
		var z: float = clampf(clump.y + sin(angle) * radius, -field_size.y * 0.5, field_size.y * 0.5)
		var yaw: float = rng.randf_range(0.0, TAU)
		var scale_jitter: float = rng.randf_range(0.75, 1.25)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale_jitter, scale_jitter, scale_jitter))
		mm.set_instance_transform(i, Transform3D(basis, center + Vector3(x, 0.0, z)))


## One blade: a tapered quad (2 triangles), root at V=1 (pinned, full
## width), tip at V=0 (sways, TIP_WIDTH_RATIO of root width) — a soft blunt
## paddle shape instead of the original single-triangle needle point, per
## the convention assets/shaders/wind_sway.gdshader's `tip = 1.0 - UV.y`
## expects. Winding doesn't need to be front-face-correct: wind_sway's
## fragment() flips NORMAL on back faces, so either side lights correctly
## regardless of instance yaw.
func _build_blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w: float = blade_width * 0.5
	var tip_half_w: float = half_w * TIP_WIDTH_RATIO

	var root_left := Vector3(-half_w, 0.0, 0.0)
	var root_right := Vector3(half_w, 0.0, 0.0)
	var tip_right := Vector3(tip_half_w, blade_height, 0.0)
	var tip_left := Vector3(-tip_half_w, blade_height, 0.0)

	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(root_left)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(root_right)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(tip_right)

	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(root_left)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(tip_right)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(tip_left)

	st.generate_normals()
	return st.commit()
