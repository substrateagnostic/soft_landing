shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// ground_patches.gdshader — soft world-space value-noise ground tint blend
// (D22 graphics-v2 ROUND 2, director's note 2: "flat single-color ground
// kills the diorama"). Blends two near-neighbor tints in big soft patches
// (3 octaves of hashed value noise, world-space so the pattern never swims
// as the camera moves) plus rare soft lighter dots. No texture assets --
// same hash-based value-noise technique as dream_sky.gdshader's clouds/
// stars, just sampled in world XZ instead of sky EYEDIR.
//
// Usage (see worlds/*.gd): duplicate per ground slab with tint_a/tint_b set
// to that world's near-neighbor pair (e.g. bramble: sage <-> warm moss).
// The ~10-15% value difference the recipe asks for is baked into the two
// tint uniforms themselves; this shader only decides WHERE each shows
// through, in patches big enough to read as "painted ground", not noise.

uniform vec4 tint_a : source_color = vec4(0.486, 0.565, 0.510, 1.0);
uniform vec4 tint_b : source_color = vec4(0.549, 0.580, 0.388, 1.0);
uniform vec4 dot_color : source_color = vec4(1.0, 0.953, 0.769, 1.0);
uniform float noise_scale : hint_range(0.01, 0.3) = 0.07; // world units per noise cell (~0.05-0.1/m per the brief)
uniform float dot_strength : hint_range(0.0, 0.3) = 0.05;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

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

void fragment() {
	vec2 p = world_pos.xz * noise_scale;
	// 3 octaves, low-frequency dominant -> big soft patches, not speckle.
	float n = value_noise(p) * 0.55
		+ value_noise(p * 2.13 + vec2(11.7, 4.2)) * 0.30
		+ value_noise(p * 4.37 + vec2(53.1, 27.6)) * 0.15;
	float blend = smoothstep(0.32, 0.68, n);
	vec3 col = mix(tint_a.rgb, tint_b.rgb, blend);

	// Occasional soft lighter dots -- sparse (top ~8% of a high-frequency
	// noise layer), softly masked, never a hard-edged speckle.
	float dot_n = value_noise(p * 9.0 + vec2(91.3, 17.9));
	float dot_mask = smoothstep(0.90, 0.98, dot_n);
	col = mix(col, dot_color.rgb, dot_mask * dot_strength);

	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
