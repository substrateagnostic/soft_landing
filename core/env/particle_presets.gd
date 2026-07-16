class_name ParticlePresets
extends RefCounted
## ParticlePresets — shared GPUParticles3D + ParticleProcessMaterial builders
## (D22 / recipes "Particles"). One place for the knobs the recipe calls
## out (turbulence, scale_curve breathing, color_ramp fade, additive glow
## billboards) so core/env/ambience.gd's fireflies/dream-motes/falling-bits
## and core/env/footstep_puff.gd + core/env/sparkle_trail.gd all build the
## same way. GPUParticles3D throughout, never CPUParticles3D (recipe note:
## GPU cost scales with `amount` even off-screen, so every caller sizes
## `amount` to what it actually needs).

## An ambient drifting glow particle (fireflies, dream-motes): sphere/box
## emission, gentle turbulence, a breathing scale curve, additive billboard.
static func make_ambient_glow(
	glow_name: String, amount: int, lifetime: float, color: Color,
	box_extents: Vector3, drift_speed: float, turbulence: bool, gravity: Vector3,
	particle_size: float
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = glow_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime * 0.5
	particles.randomness = 0.6
	particles.draw_pass_1 = _glow_quad(particle_size)
	particles.process_material = _ambient_process_material(box_extents, drift_speed, turbulence, gravity, color)
	return particles


## Re-tints a live ambient-glow particle system in place (falling leaves ->
## pollen -> mist, per-world flavor swap in core/env/ambience.gd) — rebuilds
## just the process material's color + fade ramp, no node/mesh churn.
static func retint_ambient(particles: GPUParticles3D, color: Color) -> void:
	var pm := particles.process_material as ParticleProcessMaterial
	if pm == null:
		return
	pm.color = color
	pm.color_ramp = _fade_ramp(color, 0.15, 0.85)


static func _ambient_process_material(
	box_extents: Vector3, drift_speed: float, turbulence: bool, gravity: Vector3, color: Color
) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box_extents
	pm.gravity = gravity
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 180.0
	pm.initial_velocity_min = drift_speed * 0.4
	pm.initial_velocity_max = drift_speed
	pm.turbulence_enabled = turbulence
	pm.turbulence_noise_strength = 1.0
	pm.turbulence_noise_scale = 9.0
	pm.color = color
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	pm.scale_curve = _breathing_curve()
	pm.color_ramp = _fade_ramp(color, 0.15, 0.85)
	return pm


## Fade-in/fade-out alpha ramp around a solid mid-life color (fireflies,
## dream-motes, falling leaves all share this shape; footstep puffs/trails
## use their own one-directional fade below).
static func _fade_ramp(color: Color, fade_in_at: float, fade_out_at: float) -> GradientTexture1D:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, 0.0))
	ramp.add_point(fade_in_at, Color(color.r, color.g, color.b, 1.0))
	ramp.add_point(fade_out_at, Color(color.r, color.g, color.b, 1.0))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	return ramp_tex


## Starts fully opaque, fades to transparent by `fade_out_at` (0..1 life
## fraction) — footstep puffs (fade across their whole short life) and
## sparkle trails (fade_out_at 1.0 == the shrink-to-zero scale curve alone
## does the work, color stays solid) both want a one-directional fade,
## unlike the ambient fade-in/fade-out shape above.
static func _fade_out_ramp(color: Color, fade_out_at: float) -> GradientTexture1D:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, 1.0))
	ramp.add_point(clamp(fade_out_at, 0.01, 0.99), Color(color.r, color.g, color.b, 0.0))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	return ramp_tex


static func _breathing_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1.0, 0.3))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


## The `color` argument only sizes the initial process-material ramp (see
## _color_ramp() below) — the mesh material itself always stays neutral
## white so retinting later (ParticlePresets.retint_ambient) only has to
## touch the process material, never the mesh's own material.
static func _glow_quad(particle_size: float) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(particle_size, particle_size)
	mesh.surface_set_material(0, glow_billboard_material())
	return mesh


## Radial-gradient-ish billboard: ALPHA + ADD blend, unshaded, so env glow
## (core/env/ambience.gd's WorldEnvironment) blooms the cores (recipe note).
## Vertex-color-as-albedo with a white base color means the particle's own
## color (from ParticleProcessMaterial.color / color_ramp) is the only tint
## source — no double-multiply when a caller retints at runtime.
static func glow_billboard_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.albedo_texture = _radial_gradient_texture()
	return mat


## Tiny procedural radial falloff texture (center bright -> edge transparent)
## so the additive billboard reads as a soft glow dot, no external asset.
static var _cached_radial_texture: ImageTexture = null


static func _radial_gradient_texture() -> ImageTexture:
	if _cached_radial_texture != null:
		return _cached_radial_texture
	const SIZE: int = 16
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var d: float = Vector2(x - SIZE * 0.5 + 0.5, y - SIZE * 0.5 + 0.5).length() / (SIZE * 0.5)
			var falloff: float = clamp(1.0 - d, 0.0, 1.0)
			falloff = falloff * falloff
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, falloff))
	_cached_radial_texture = ImageTexture.create_from_image(image)
	return _cached_radial_texture


## One-shot burst (footstep puffs): explosiveness 1.0, small local box.
static func make_burst(burst_name: String, amount: int, lifetime: float, color: Color, particle_size: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = burst_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
	particles.draw_pass_1 = _glow_quad(particle_size)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.1
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 60.0
	pm.gravity = Vector3(0.0, -1.5, 0.0)
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = color
	pm.color_ramp = _fade_out_ramp(color, 0.4)
	particles.process_material = pm
	return particles


## Continuous trail (carried dreamlings/sparkle moves): point emission,
## shrink-to-zero, additive; caller toggles `emitting` via set_emitting().
static func make_trail(trail_name: String, amount: int, lifetime: float, color: Color, particle_size: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = trail_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.emitting = false
	particles.draw_pass_1 = _glow_quad(particle_size)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 40.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0)) # shrink-to-zero
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	pm.scale_curve = scale_tex
	pm.color = color
	pm.color_ramp = _fade_out_ramp(color, 0.7)
	particles.process_material = pm
	return particles
