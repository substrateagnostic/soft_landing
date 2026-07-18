shader_type spatial;
// quilted_blanket.gdshader — D27 fort legibility (producer playtest: a
// bare milk-white wall filled half the screen and read as a missing
// texture). The pillow fort's walls are BLANKETS: a soft two-tone quilt
// checker with stitched seams and a gentle center puff, computed from
// world position per dominant face axis (the walls are plain BoxMeshes,
// so planar mapping per face is exact — no UVs needed, no texture asset).
// Soft-wrapped diffuse to match the plush look everywhere else.
render_mode diffuse_lambert_wrap;

uniform vec4 color_a : source_color = vec4(0.961, 0.949, 0.910, 1.0); // milk white
uniform vec4 color_b : source_color = vec4(0.918, 0.847, 0.796, 1.0); // warm sand
uniform float patch_size = 0.9;
uniform float seam_width = 0.05;
uniform float seam_darken = 0.2;
uniform float puff = 0.4;

varying vec3 world_pos;
varying vec3 world_normal;


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}


void fragment() {
	vec3 an = abs(world_normal);
	vec2 uv;
	if (an.y > max(an.x, an.z)) {
		uv = world_pos.xz; // roof / floor faces
	} else if (an.x > an.z) {
		uv = world_pos.zy; // side walls
	} else {
		uv = world_pos.xy; // front / back walls
	}

	vec2 cell = floor(uv / patch_size);
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 base = mix(color_a.rgb, color_b.rgb, checker);

	vec2 f = fract(uv / patch_size);
	float d = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float seam = smoothstep(seam_width, seam_width * 2.2, d);
	float bulge = smoothstep(0.0, 0.5, d);

	vec3 col = base * mix(1.0 - seam_darken, 1.0, seam);
	col *= 1.0 - puff * 0.12 * (1.0 - bulge);
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
