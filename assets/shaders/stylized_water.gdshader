shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_lambert, specular_schlick_ggx;
// stylized_water.gdshader — calm absorption-based lake water (D22 / recipes
// "Water (Wisp's lake)"). Original implementation of the documented
// technique (Beer's-law depth-color absorption + shoreline/whale foam +
// fresnel + gentle vertex waves), written against Godot 4.6 Forward+'s
// depth-texture + INV_PROJECTION_MATRIX unprojection rather than forking the
// cited GodotShaders asset — see graphics-v2-VERIFY.md for the honest note
// on that substitution. Retinted dusk-blue -> deep per Wisp's palette, wave
// amplitude kept low so the register stays "calm lake", not "ocean".

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_linear_mipmap;
uniform vec3 shallow_color : source_color = vec3(0.20, 0.30, 0.42);
uniform vec3 deep_color : source_color = vec3(0.086, 0.098, 0.176);
uniform vec3 foam_color : source_color = vec3(0.85, 0.90, 0.96);
uniform float depth_fade_distance : hint_range(0.1, 12.0) = 3.5;
uniform float foam_distance : hint_range(0.0, 2.0) = 0.35;
uniform float wave_amplitude : hint_range(0.0, 0.3) = 0.045;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;
uniform float alpha_shallow : hint_range(0.0, 1.0) = 0.55;
uniform float alpha_deep : hint_range(0.0, 1.0) = 0.92;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave = sin(world_pos.x * 0.6 + TIME * wave_speed) * cos(world_pos.z * 0.5 + TIME * wave_speed * 0.8);
	VERTEX.y += wave * wave_amplitude;
}

void fragment() {
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float scene_depth = -view.z;
	float pixel_depth = -VERTEX.z;
	float depth_diff = max(scene_depth - pixel_depth, 0.0);

	float depth_fade = clamp(depth_diff / depth_fade_distance, 0.0, 1.0);
	vec3 color = mix(shallow_color, deep_color, depth_fade);

	float foam = 1.0 - smoothstep(0.0, foam_distance, depth_diff);
	color = mix(color, foam_color, foam);

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	color = mix(color, foam_color, fresnel * 0.18);

	ALBEDO = color;
	ALPHA = mix(alpha_shallow, alpha_deep, depth_fade);
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
}
