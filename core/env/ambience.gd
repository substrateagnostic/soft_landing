class_name Ambience
extends Node3D
## Ambience — per-world lighting/environment/sky/fog/particle rig (D22,
## docs/research/v2/visuals_recipes.md). Owned by scenes/main.gd:
## `setup(world_environment)` builds the post stack + sky + moon key light +
## shared ambient particle systems ONCE against the WorldEnvironment node
## already present in scenes/main.tscn (out of this agent's territory —
## reused, never replaced); `apply_world(world_id)` then reconfigures
## colors/positions on every world load/switch. Nothing is rebuilt per
## switch — only uniforms/parameters change — so switching worlds never
## re-allocates GPUParticles3D or shader resources.
##
## Replaces main.gd's old single `_ensure_moonlight()` DirectionalLight3D;
## the moon key light lives here now, alongside the ambient particle systems
## shared by every world (dream-motes always-on; fireflies and falling
## leaves/pollen/mist enabled and recolored per-world per WORLD_CONFIGS
## below). Per-world PRACTICAL fill lights (porch lanterns, window glow)
## stay where they already were: built by each world's own script, right
## next to the prop they light (pillow_fort.gd's LanternGlow/InteriorGlow,
## marmalade.gd's per-house WindowGlow) — this file only adds the warm
## fills those two worlds' scripts didn't already have (bramble, wisp; see
## worlds/bramble/bramble.gd's _build_ambient_lighting() and
## worlds/wisp/wisp.gd's equivalent).

const SKY_SHADER_PATH: String = "res://assets/shaders/dream_sky.gdshader"
const DEFAULT_WORLD_ID: String = "_default"

# Coordinates below mirror constants already declared in each world's own
# script (bramble.gd's HAUNCH_CENTER/FUR_PATCH_*, wisp.gd's SHORE_CENTER/
# LAKE_CENTER, marmalade.gd's SPAWN_PIP/RIDGE_CENTER, pillow_fort.gd's
# FORT_CENTER) — this file never reaches into a world's live tree, it just
# knows roughly where that geometry sits so particle boxes/firefly clouds
# read as "in the scene", not centered on empty air.
const WORLD_CONFIGS: Dictionary = {
	"pillow_fort": {
		"moon_color": Color(0.85, 0.87, 1.0), "moon_energy": 1.0,
		"moon_rotation_degrees": Vector3(-55.0, -30.0, 0.0),
		# ROUND 2 (director's note 3): cosmetic disc position only (see
		# dream_sky.gdshader's moon_azimuth_degrees/moon_elevation_degrees
		# comment). Elevation kept just under the default camera's visible
		# sky ceiling (base_pitch -32 + half of fov 60 = -2 deg true
		# elevation) with margin. Azimuth is NOT dead-center on
		# ClearingCameraHint's yaw (0.0): a first still at azimuth 0 showed
		# the disc hidden behind the fort's own solid front wall, which sits
		# directly in that look direction a few meters out -- +30 deg moves
		# it into the open sky visible past the wall's edge (confirmed
		# against a second still, see graphics-v2-VERIFY.md).
		"moon_visual_azimuth": 30.0, "moon_visual_elevation": -9.0,
		"zenith": Color("2E3B5E"), "horizon": Color(0.40, 0.36, 0.48), "ground": Color(0.10, 0.10, 0.16),
		"fog_tint": Color("7C9082"), "fog_density": 0.010,
		"ambient_energy": 0.95,
		"play_center": Vector3(0.0, 1.5, -3.0), "play_extents": Vector3(11.0, 3.5, 11.0),
		"fireflies": true, "firefly_center": Vector3(0.0, 1.4, -4.0), "firefly_extents": Vector3(3.0, 1.2, 2.0),
		"leaf_flavor": "pollen", "leaf_color": Color("FFF3C4"),
		"leaf_center": Vector3(0.0, 2.0, 0.0), "leaf_extents": Vector3(9.0, 3.0, 9.0),
	},
	"bramble": {
		"moon_color": Color(0.82, 0.85, 1.0), "moon_energy": 0.95,
		"moon_rotation_degrees": Vector3(-48.0, -35.0, 0.0),
		# ROUND 2 (director's note 3): MeadowApproachHint's yaw (-90, facing
		# +X toward the bear) is where the huge haunch/shoulder mound fills
		# the frame -- at this close a spawn distance the mound's angular
		# radius is enormous. The only open sky in any still is a thin sliver
		# in the extreme top-left corner (worked out via the camera's actual
		# forward/right/up basis at yaw -90/pitch -32/fov 60, not eyeballed):
		# -49 azimuth / -2.5 elevation lands the disc deep in that corner
		# with real margin, not right on the mound's edge like -60/-3 was
		# (confirmed against a still, see graphics-v2-VERIFY.md).
		"moon_visual_azimuth": -49.0, "moon_visual_elevation": -2.5,
		# ROUND 2 (director's note 5, "warm bramble up"): zenith/horizon/
		# ground lifted from near-black cold navy toward the requested
		# #4A4A6E-#5E5470 plum-warm range -- horizon sits at the range's
		# lighter end exactly, zenith/ground follow the same direction so
		# the whole sky reads warmer, not just a brighter strip at the rim.
		"zenith": Color(0.243, 0.227, 0.337), "horizon": Color("5E5470"), "ground": Color(0.227, 0.196, 0.282),
		"fog_tint": Color(0.455, 0.361, 0.380), "fog_density": 0.007,
		"ambient_energy": 0.95,
		"play_center": Vector3(-20.0, 3.0, 0.0), "play_extents": Vector3(35.0, 8.0, 25.0),
		"fireflies": true, "firefly_center": Vector3(-22.0, 3.2, -2.0), "firefly_extents": Vector3(6.0, 2.0, 6.0),
		"leaf_flavor": "leaves", "leaf_color": Color("8A6552"),
		"leaf_center": Vector3(-10.0, 8.0, 0.0), "leaf_extents": Vector3(40.0, 4.0, 20.0),
	},
	"wisp": {
		"moon_color": Color(0.88, 0.92, 1.0), "moon_energy": 1.05,
		"moon_rotation_degrees": Vector3(-52.0, -20.0, 0.0),
		# ROUND 2: ShoreApproachHint shares bramble's MeadowApproachHint's
		# exact yaw/pitch (-90/-32), so the same worked-out camera-basis
		# solution lands in the same deep top-left corner (see bramble's
		# WORLD_CONFIGS comment for the derivation).
		"moon_visual_azimuth": -49.0, "moon_visual_elevation": -2.5,
		"zenith": Color(0.06, 0.08, 0.16), "horizon": Color(0.16, 0.20, 0.32), "ground": Color(0.04, 0.05, 0.10),
		"fog_tint": Color("22304F"), "fog_density": 0.009,
		"ambient_energy": 0.9,
		"play_center": Vector3(0.0, 2.0, 0.0), "play_extents": Vector3(55.0, 10.0, 25.0),
		"fireflies": false, "firefly_center": Vector3.ZERO, "firefly_extents": Vector3.ZERO,
		"leaf_flavor": "mist", "leaf_color": Color("9FE8E0"),
		"leaf_center": Vector3(-10.0, 1.0, 0.0), "leaf_extents": Vector3(45.0, 1.5, 20.0),
	},
	"marmalade": {
		"moon_color": Color(0.86, 0.86, 0.98), "moon_energy": 0.95,
		"moon_rotation_degrees": Vector3(-50.0, -40.0, 0.0),
		# ROUND 2: VillageApproachHint shares bramble's MeadowApproachHint's
		# exact yaw/pitch (-90/-32), so the same worked-out camera-basis
		# solution lands in the same deep top-left corner (see bramble's
		# WORLD_CONFIGS comment for the derivation).
		"moon_visual_azimuth": -49.0, "moon_visual_elevation": -2.5,
		"zenith": Color(0.10, 0.08, 0.13), "horizon": Color(0.34, 0.24, 0.24), "ground": Color(0.08, 0.07, 0.10),
		"fog_tint": Color("D98E4A"), "fog_density": 0.007,
		"ambient_energy": 0.85,
		"play_center": Vector3(-45.0, 4.0, 0.0), "play_extents": Vector3(30.0, 6.0, 20.0),
		"fireflies": false, "firefly_center": Vector3.ZERO, "firefly_extents": Vector3.ZERO,
		"leaf_flavor": "leaves", "leaf_color": Color("B4654A"),
		"leaf_center": Vector3(-45.0, 5.0, 0.0), "leaf_extents": Vector3(30.0, 3.0, 20.0),
	},
	DEFAULT_WORLD_ID: {
		"moon_color": Color(0.82, 0.84, 1.0), "moon_energy": 0.85,
		"moon_rotation_degrees": Vector3(-50.0, -30.0, 0.0),
		"moon_visual_azimuth": 0.0, "moon_visual_elevation": -9.0,
		"zenith": Color("2E3B5E"), "horizon": Color(0.4, 0.36, 0.46), "ground": Color(0.08, 0.08, 0.13),
		"fog_tint": Color("7C9082"), "fog_density": 0.008,
		"ambient_energy": 0.8,
		"play_center": Vector3.ZERO, "play_extents": Vector3(15.0, 4.0, 15.0),
		"fireflies": false, "firefly_center": Vector3.ZERO, "firefly_extents": Vector3.ZERO,
		"leaf_flavor": "pollen", "leaf_color": Color("FFF3C4"),
		"leaf_center": Vector3.ZERO, "leaf_extents": Vector3(15.0, 3.0, 15.0),
	},
}

var _world_environment: WorldEnvironment = null
var _environment: Environment = null
var _sky_material: ShaderMaterial = null
var _moon: DirectionalLight3D = null
var _fireflies: GPUParticles3D = null
var _dream_motes: GPUParticles3D = null
var _falling_bits: GPUParticles3D = null

var _is_setup: bool = false


func setup(world_environment: WorldEnvironment) -> void:
	if _is_setup:
		return
	_is_setup = true
	_world_environment = world_environment
	_build_environment()
	_build_moon()
	_build_particles()


## Called by scenes/main.gd from _ready() (after the first _load_world) and
## from _switch_world() (after the door-triggered world swap) — the single
## seam every world's lighting/sky/fog/particle flavor flows through.
func apply_world(world_id: String) -> void:
	if not _is_setup:
		push_warning("Ambience: apply_world called before setup()")
		return
	var cfg: Dictionary = WORLD_CONFIGS.get(world_id, WORLD_CONFIGS[DEFAULT_WORLD_ID]) as Dictionary
	_apply_sky_and_fog(cfg)
	_apply_moon(cfg)
	_apply_particles(cfg)


# --- Post stack / sky / fog (deliverables 1-2) ------------------------------

func _build_environment() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY

	_sky_material = ShaderMaterial.new()
	_sky_material.shader = load(SKY_SHADER_PATH) as Shader
	var sky := Sky.new()
	sky.sky_material = _sky_material
	# INCREMENTAL, not REALTIME: REALTIME recomputes the full radiance
	# cubemap (every mip/roughness layer, for every object's ambient/
	# reflection sampling) EVERY frame -- measured 3.9 fps avg on bramble
	# with it. INCREMENTAL is Godot's own recommended mode for a
	# continuously-animated sky (TIME-driven clouds/stars): it spreads the
	# radiance update across several frames instead of redoing it whole
	# each frame, which this stylized non-physical sky doesn't need anyway.
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_64 # default 256 is overkill for a flat-band painted sky
	_environment.sky = sky

	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_sky_contribution = 0.7
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# AgX (recipe: preserves hue in the honey/cream overexposure range that
	# Filmic/ACES collapse to yellow), paired with a modest saturation/
	# contrast lift per the recipe (it mutes midtone saturation).
	_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_environment.adjustment_enabled = true
	_environment.adjustment_saturation = 1.15
	_environment.adjustment_contrast = 1.04
	_environment.adjustment_brightness = 1.0

	# Soft-light glow so honey/cream tones bloom; capped mip levels for perf
	# per the recipe ("cap glow levels 4-5").
	# ROUND 2 (director's note 4, "dreamlings should bloom"): dreamlings
	# (worlds/common/dreamling.tscn, FORBIDDEN territory) are already
	# emissive at 2x -- the miss was on this side, not theirs: levels 3/4
	# alone are wide-mip-only, which reads as a diffuse ambient wash on
	# LARGE bright areas (windows, lantern glow) but barely registers on a
	# small ~0.35 m sphere. Added levels 1/2 give small bright objects their
	# own tight halo; threshold/intensity nudged so it actually shows at
	# gameplay distance without blowing out the honey/cream palette broadly
	# (still well under the recipe's "no washing the register out" floor --
	# verified against a still, not assumed, see graphics-v2-VERIFY.md).
	_environment.glow_enabled = true
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_environment.glow_hdr_threshold = 0.78
	_environment.glow_intensity = 1.05
	_environment.glow_strength = 1.1
	for level: int in range(7):
		_environment.set_glow_level(level, 0.0)
	_environment.set_glow_level(1, 0.30)
	_environment.set_glow_level(2, 0.45)
	_environment.set_glow_level(3, 0.55)
	_environment.set_glow_level(4, 0.35)

	# SSAO OFF — found (not shipped) during this pass: at ANY tested
	# intensity, Forward+ SSAO here computed near-total occlusion across
	# large flat/curved surfaces at this project's scale (10-20 m mounds),
	# which multiplies straight into ambient/indirect light with no
	# light_affect escape hatch -- it was crushing the entire visible
	# ground to near-black regardless of moon/ambient energy (confirmed by
	# toggling ssao_enabled alone at 4x diagnostic light energy: ground
	# stayed black with SSAO on, fully recovered with it off). Recipe
	# calls SSAO the lowest-value knob in the post stack ("low intensity
	# only... nonzero Light Affect") — cutting it entirely was the right
	# trade against the design floor's non-negotiable "night must stay
	# bright and readable." See graphics-v2-VERIFY.md for the repro.
	_environment.ssao_enabled = false

	# Depth fog + volumetric haze; colors/density tinted per-world below.
	# fog_sky_affect = 0.0: the depth fog only shades geometry, never
	# repaints the sky itself -- the sky shader already owns the sky's own
	# mood via its own uniforms.
	_environment.fog_enabled = true
	_environment.fog_sky_affect = 0.0
	_environment.fog_depth_begin = 12.0
	_environment.fog_depth_end = 150.0
	_environment.fog_depth_curve = 1.2

	# volumetric_fog_emission_energy = 0.0: no flat extra light injected
	# into the froxel volume -- the fog only tints/scatters light that's
	# already there (moon + ambient) instead of also emitting on top of it.
	_environment.volumetric_fog_enabled = true
	_environment.volumetric_fog_length = 50.0
	_environment.volumetric_fog_detail_spread = 2.0
	_environment.volumetric_fog_gi_inject = 0.0
	_environment.volumetric_fog_ambient_inject = 0.1
	_environment.volumetric_fog_emission_energy = 0.0

	_world_environment.environment = _environment


func _apply_sky_and_fog(cfg: Dictionary) -> void:
	_sky_material.set_shader_parameter("zenith_color", cfg["zenith"])
	_sky_material.set_shader_parameter("horizon_color", cfg["horizon"])
	_sky_material.set_shader_parameter("ground_color", cfg["ground"])
	_sky_material.set_shader_parameter("moon_color", cfg["moon_color"])
	# ROUND 2 (director's note 3): cosmetic disc placement, decoupled from
	# the moon key light's actual direction -- see dream_sky.gdshader's
	# moon_azimuth_degrees/moon_elevation_degrees uniform comment for why.
	_sky_material.set_shader_parameter("moon_azimuth_degrees", cfg["moon_visual_azimuth"])
	_sky_material.set_shader_parameter("moon_elevation_degrees", cfg["moon_visual_elevation"])

	var fog_tint: Color = cfg["fog_tint"]
	_environment.fog_light_color = fog_tint
	_environment.fog_density = cfg["fog_density"]
	_environment.volumetric_fog_density = float(cfg["fog_density"]) * 0.7
	_environment.volumetric_fog_albedo = fog_tint
	_environment.volumetric_fog_emission = fog_tint
	_environment.ambient_light_energy = cfg["ambient_energy"]


# --- Lighting rig (deliverable 3) -------------------------------------------

func _build_moon() -> void:
	_moon = DirectionalLight3D.new()
	_moon.name = "MoonKeyLight"
	_moon.shadow_enabled = true
	_moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(_moon)


func _apply_moon(cfg: Dictionary) -> void:
	_moon.light_color = cfg["moon_color"]
	_moon.light_energy = cfg["moon_energy"]
	_moon.rotation_degrees = cfg["moon_rotation_degrees"]


# --- Particles (deliverable 4) ----------------------------------------------

func _build_particles() -> void:
	_fireflies = ParticlePresets.make_ambient_glow(
		"Fireflies", 32, 6.0, Color("F2C879"), Vector3(3.0, 1.2, 3.0), 0.25, true, Vector3.ZERO, 0.10
	)
	add_child(_fireflies)

	_dream_motes = ParticlePresets.make_ambient_glow(
		"DreamMotes", 180, 9.0, Color("FFF3C4"), Vector3(15.0, 4.0, 15.0), 0.15, true, Vector3(0.0, -0.05, 0.0), 0.06
	)
	add_child(_dream_motes)

	_falling_bits = ParticlePresets.make_ambient_glow(
		"FallingBits", 90, 7.0, Color("8A6552"), Vector3(20.0, 3.0, 15.0), 0.2, true, Vector3(0.0, -0.35, 0.0), 0.08
	)
	add_child(_falling_bits)


func _apply_particles(cfg: Dictionary) -> void:
	var fireflies_on: bool = cfg["fireflies"]
	_fireflies.emitting = fireflies_on
	_fireflies.visible = fireflies_on
	if fireflies_on:
		_fireflies.position = cfg["firefly_center"]
		(_fireflies.process_material as ParticleProcessMaterial).emission_box_extents = cfg["firefly_extents"]

	_dream_motes.position = cfg["play_center"]
	(_dream_motes.process_material as ParticleProcessMaterial).emission_box_extents = cfg["play_extents"]

	var leaf_flavor: String = cfg["leaf_flavor"]
	var leaf_color: Color = cfg["leaf_color"]
	_falling_bits.position = cfg["leaf_center"]
	var leaf_pm := _falling_bits.process_material as ParticleProcessMaterial
	leaf_pm.emission_box_extents = cfg["leaf_extents"]
	# Mist drifts near-weightless; leaves/pollen actually fall.
	leaf_pm.gravity = Vector3(0.0, -0.05, 0.0) if leaf_flavor == "mist" else Vector3(0.0, -0.35, 0.0)
	ParticlePresets.retint_ambient(_falling_bits, leaf_color)


# --- THE WAKING (D28) --------------------------------------------------------

## begin_dawn — the game's one and only sunrise. Tweens the live sky
## shader, fog, ambient and the moon key light from wherever the current
## world's dusk left them toward a soft pre-dawn gold over `duration`
## seconds. One-way by design: the Waking ends in the title screen, and a
## fresh boot rebuilds the night — dawn never needs undoing in-scene.
## Called by worlds/pillow_fort/waking_sequence.gd (duck-typed).

const DAWN_ZENITH: Color = Color("8B93BE") # lightening periwinkle
const DAWN_HORIZON: Color = Color("F2C9A0") # warm gold-rose, the sun almost here
const DAWN_GROUND: Color = Color("C9A89A")
const DAWN_MOON_TINT: Color = Color("F5EAD0") # the moon going pale and gentle
const DAWN_LIGHT_COLOR: Color = Color("FFE3BD")
const DAWN_LIGHT_ENERGY: float = 1.15
const DAWN_FOG_COLOR: Color = Color("E8C9AE")
const DAWN_AMBIENT_ENERGY: float = 1.6


func begin_dawn(duration: float) -> void:
	if not _is_setup:
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	_tween_sky_color(tween, "zenith_color", DAWN_ZENITH, duration)
	_tween_sky_color(tween, "horizon_color", DAWN_HORIZON, duration)
	_tween_sky_color(tween, "ground_color", DAWN_GROUND, duration)
	_tween_sky_color(tween, "moon_color", DAWN_MOON_TINT, duration)
	tween.tween_property(_moon, "light_color", DAWN_LIGHT_COLOR, duration)
	tween.tween_property(_moon, "light_energy", DAWN_LIGHT_ENERGY, duration)
	tween.tween_property(_environment, "fog_light_color", DAWN_FOG_COLOR, duration)
	tween.tween_property(_environment, "ambient_light_energy", DAWN_AMBIENT_ENERGY, duration)
	print("DAWN %s" % JSON.stringify({"duration": duration}))


func _tween_sky_color(tween: Tween, param: String, target: Color, duration: float) -> void:
	var from: Color = _sky_material.get_shader_parameter(param)
	tween.tween_method(
		func(c: Color) -> void: _sky_material.set_shader_parameter(param, c),
		from, target, duration
	)
