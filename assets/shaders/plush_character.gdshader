shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;
// plush_character.gdshader — soft-toy character material (D22 / recipes
// "Character rendering"). No outlines; softness comes from a fresnel rim
// tied to the scene's key light color (so it reads as moonlight-kissed
// fabric, not a fixed rim tint) plus fake-SSS wrap lighting so plush edges
// never go fully dark. One shader, many parts: duplicate the accompanying
// core/env/plush_material.tres per mesh and only change `albedo_color` to
// repaint a character's existing part colors (see graphics-v2-VERIFY.md for
// the one-line apply instructions).

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Textured meshes (the rigged kids, Callie) keep their painted faces:
// albedo_texture defaults to white so flat-color parts are unaffected.
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform vec3 rim_color : source_color = vec3(1.0, 0.98, 0.9);
uniform float rim_width : hint_range(0.5, 8.0) = 3.0;
uniform float rim_strength : hint_range(0.0, 3.0) = 1.0;
uniform float sss_factor : hint_range(0.0, 1.0) = 0.4;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.75;

void fragment() {
	ALBEDO = albedo_color.rgb * texture(albedo_texture, UV).rgb;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}

void light() {
	// Wrapped diffuse (fake SSS): the terminator slides past 90° by
	// sss_factor instead of cutting hard, so plush edges never go fully
	// dark — this IS the base diffuse term, not an addition to one
	// (recipes: Performant SSS approx / half-Lambert wrap).
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp((ndl + sss_factor) / (1.0 + sss_factor), 0.0, 1.0);
	DIFFUSE_LIGHT += wrap * LIGHT_COLOR / PI * ALBEDO * ATTENUATION;
	// Fresnel rim, colored by the incoming light so it auto-tints to
	// whichever world's moonlight is lighting the character.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_width);
	SPECULAR_LIGHT += rim * rim_color * LIGHT_COLOR / PI * rim_strength * ATTENUATION;
}
