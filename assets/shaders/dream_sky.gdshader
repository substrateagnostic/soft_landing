shader_type sky;
// dream_sky.gdshader — painted procedural night sky (D22 / visuals_recipes.md
// "Sky"). Gradient bands dusk-blue -> deep navy, hashed star field, a BIG
// soft stylized moon disc with halo aligned to the scene's key light
// (LIGHT0_*, populated automatically by the moon DirectionalLight3D core/env/
// ambience.gd builds), and two layers of slow drifting cloud noise. Every
// color/knob is a uniform so core/env/ambience.gd can retint per world
// without a second shader file.

uniform vec3 zenith_color : source_color = vec3(0.086, 0.098, 0.176);
uniform vec3 horizon_color : source_color = vec3(0.243, 0.286, 0.408);
uniform vec3 ground_color : source_color = vec3(0.055, 0.062, 0.108);
uniform vec3 moon_color : source_color = vec3(1.0, 0.965, 0.86);
uniform vec3 cloud_color : source_color = vec3(0.92, 0.90, 0.97);
uniform float moon_size : hint_range(0.02, 0.3) = 0.09;
uniform float moon_halo_size : hint_range(0.0, 0.5) = 0.16;
uniform float star_density : hint_range(0.0, 1.0) = 0.4;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.32;
uniform float cloud_speed : hint_range(0.0, 0.2) = 0.015;

// ROUND 2 (director's note 3, "the moon must be in frame"): the drawn disc's
// position is now driven by these two uniforms, NOT LIGHT0_DIRECTION.
// Why: core/camera/camera_rig.gd's default third-person framing (base_pitch
// -32 deg, fov 60 vertical) only ever shows sky between roughly -62 deg and
// -2 deg of true elevation -- it's a steep down-look at the players, not a
// view of the open sky. The moon key light (core/env/ambience.gd's _moon,
// still ~40-55 deg elevation per world) needs to stay up there for
// physically sane downward shadows/ambient; forcing THAT light down to
// -10 deg so its disc would land in frame would mean the "moon" shines
// upward on the whole scene. Decoupling lets the light keep lighting the
// world properly while the cosmetic disc gets placed wherever the default
// gameplay camera can actually see it -- same spirit as this being a
// stylized non-physical sky already (see ambience.gd's Sky.PROCESS_MODE_
// INCREMENTAL comment). Azimuth uses the exact same convention as every
// world's CameraHint.yaw_degrees (0 = -Z, -90 = +X, +90 = -X), so
// core/env/ambience.gd just copies each world's primary hint's yaw in.
uniform float moon_azimuth_degrees : hint_range(-180.0, 180.0) = 0.0;
uniform float moon_elevation_degrees : hint_range(-90.0, 90.0) = -10.0;

// Cheap hash-based value noise -- no textures required (recipe: "procedural,
// no textures needed").
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void sky() {
	float horizon_mix = smoothstep(-0.06, 0.4, EYEDIR.y);
	vec3 col = mix(horizon_color, zenith_color, horizon_mix);
	if (EYEDIR.y < 0.0) {
		col = mix(horizon_color, ground_color, smoothstep(0.0, -0.45, EYEDIR.y));
	}

	// Hashed star field, upper sky only, gently twinkling.
	if (EYEDIR.y > 0.03) {
		vec2 star_uv = EYEDIR.xz / max(EYEDIR.y, 0.06);
		float star = hash21(floor(star_uv * 55.0));
		float twinkle = 0.55 + 0.45 * sin(TIME * 2.2 + star * 40.0);
		float star_mask = step(1.0 - star_density * 0.025, star) * twinkle;
		col += vec3(star_mask) * smoothstep(0.0, 0.25, EYEDIR.y);
	}

	// Two drifting cloud-noise layers, faded out near the horizon/ground.
	vec2 cloud_uv1 = EYEDIR.xz * 1.4 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.35);
	vec2 cloud_uv2 = EYEDIR.xz * 2.8 - vec2(TIME * cloud_speed * 0.55, TIME * cloud_speed * 0.18);
	float clouds = value_noise(cloud_uv1) * 0.6 + value_noise(cloud_uv2) * 0.4;
	float cloud_mask = smoothstep(1.0 - cloud_coverage, 1.0, clouds) * smoothstep(0.0, 0.3, EYEDIR.y);
	col = mix(col, cloud_color, cloud_mask * 0.55);

	// BIG stylized moon disc + soft halo. Position driven by moon_azimuth_
	// degrees/moon_elevation_degrees (see the uniform declarations' ROUND 2
	// comment) instead of LIGHT0_DIRECTION -- azimuth 0 matches EYEDIR
	// looking down -Z, +/-90 matches +-X, same convention CameraHint.
	// yaw_degrees already uses everywhere else in this codebase.
	float moon_az = radians(moon_azimuth_degrees);
	float moon_el = radians(moon_elevation_degrees);
	vec3 moon_dir = normalize(vec3(-sin(moon_az) * cos(moon_el), sin(moon_el), -cos(moon_az) * cos(moon_el)));
	float moon_dist = distance(EYEDIR, moon_dir);
	float moon_halo = 1.0 - smoothstep(moon_size, moon_size + moon_halo_size, moon_dist);
	float moon_disc = 1.0 - smoothstep(moon_size * 0.82, moon_size, moon_dist);
	col = mix(col, moon_color, moon_halo * moon_halo * 0.5);
	col = mix(col, moon_color * 1.15, moon_disc);

	COLOR = col;
}
