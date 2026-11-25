shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float power : hint_range(0.0, 1.0) = 0.35;
uniform bool glow_enabled = true;

void fragment() {
	float along = clamp(UV.y, 0.0, 1.0);

	vec3 cyan = vec3(0.04, 0.78, 1.0);
	vec3 violet = vec3(0.54, 0.16, 0.96);
	vec3 ember = vec3(1.0, 0.24, 0.08);

	vec3 shaft = mix(cyan, violet, smoothstep(0.0, 0.68, along));
	vec3 tip = mix(violet, ember, smoothstep(0.22, 1.0, power));
	vec3 colour = mix(shaft, tip, smoothstep(0.40, 1.0, along) * (0.28 + 0.72 * power));

	float top = smoothstep(0.15, 0.95, clamp(NORMAL.y, 0.0, 1.0));
	vec3 lit = colour * mix(0.58, 1.02, top);

	ALBEDO = lit;
	METALLIC = 0.12;
	ROUGHNESS = mix(0.42, 0.30, power);
	SPECULAR = 0.28;

	float emission_strength = glow_enabled ? (0.05 + power * 0.22) : 0.03;
	EMISSION = colour * emission_strength;
	ALPHA = 1.0;
}
