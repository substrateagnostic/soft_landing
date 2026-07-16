shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled, shadows_disabled;
// wind_sway.gdshader — full-geometry grass/reed blade sway (D22 / recipes
// "Wind & vegetation"). Root pinned, tip swaying; per-instance phase comes
// free from NODE_POSITION_WORLD (no per-instance uniform array needed for a
// MultiMesh field). Blade UV convention (core/env/grass_field.gd): V=0 at
// the tip, V=1 at the root, so `tip = 1.0 - UV.y` is 1.0 at the swaying tip
// and 0.0 at the pinned root.

uniform vec4 base_color : source_color = vec4(0.486, 0.565, 0.510, 1.0);
uniform vec4 tip_color : source_color = vec4(0.62, 0.70, 0.62, 1.0);
uniform float sway_strength : hint_range(0.0, 0.5) = 0.12;
uniform float sway_speed : hint_range(0.0, 3.0) = 1.0;

void vertex() {
	float tip = 1.0 - UV.y;
	float phase = NODE_POSITION_WORLD.x * 0.6 + NODE_POSITION_WORLD.z * 0.4;
	VERTEX.x += sin(phase + TIME * 1.25 * sway_speed + UV.y) * tip * sway_strength * 0.8;
	VERTEX.z += cos(phase + TIME * 0.45 * sway_speed + UV.y) * tip * sway_strength;
	COLOR = mix(base_color, tip_color, tip);
}

void fragment() {
	// ROUND 2 fix (director's note 1, "grass reads as cold dark spikes"):
	// two compounding causes.
	// (1) Each blade is a single flat double-sided quad (cull_disabled) but
	//     the generated NORMAL only ever points out of the FRONT face --
	//     from every angle where you're looking at a blade's back face
	//     (half of them, given random per-instance yaw), the lighting model
	//     saw a normal pointing AWAY from the moon key light and clamped
	//     N.L to 0. Flipping NORMAL on back faces fixes that half.
	// (2) Even correctly two-sided, a flat blade's normal is nearly
	//     HORIZONTAL (perpendicular to its own mostly-vertical plane) while
	//     the moon key light sits ~40-55 deg up -- most of the light's
	//     energy is in its vertical component, which a horizontal normal
	//     can never catch, so even well-facing blades read as a near-black
	//     silhouette under strict Lambert (confirmed: after fix (1) alone,
	//     blades were still uniformly dark in an actual screenshot, not
	//     just "half dark" -- this is why). diffuse_lambert_wrap (render
	//     mode above) softens the N.L falloff instead of hard-clamping it,
	//     plus a small flat emission floor below guarantees blades never
	//     go fully black regardless of facing -- both are standard
	//     stylized-foliage tricks, and match the design floor's
	//     non-negotiable "night must stay bright and readable". First try
	//     at an 0.18x emission floor was still visibly darker than the
	//     ground in an actual screenshot (ground gets ~0.7 sky ambient
	//     contribution the blades' near-horizontal normals catch far less
	//     of); raised to 0.6x so the floor alone reads close to the
	//     unlit tint, with direct+ambient lighting still adding real
	//     brightness/shading variation on top for blades that ARE well-lit.
	vec3 n = NORMAL;
	if (!FRONT_FACING) {
		n = -n;
	}
	NORMAL = n;
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * 0.6;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}
