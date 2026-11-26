shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float power : hint_range(0.0, 1.0) = 0.35;
uniform float shake : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float heat = clamp(power, 0.0, 1.0);
	vec3 coral = vec3(1.0, 0.38, 0.16);
	vec3 scarlet = vec3(0.86, 0.08, 0.06);
	vec3 blood = vec3(0.28, 0.01, 0.02);
	vec3 colour = mix(coral, scarlet, smoothstep(0.0, 0.55, heat));
	colour = mix(colour, blood, smoothstep(0.45, 1.0, heat));

	float top = smoothstep(0.12, 0.95, clamp(NORMAL.y, 0.0, 1.0));
	vec3 lit = colour * mix(0.52, 1.05, top);

	ALBEDO = lit;
	METALLIC = mix(0.08, 0.22, heat);
	ROUGHNESS = mix(0.46, 0.22, heat);
	SPECULAR = 0.32;

	float pulse = 1.0 + shake * 0.55 * sin(TIME * 42.0);
	float emission_strength = 0.06 + heat * 0.38 + shake * 0.22;
	EMISSION = colour * emission_strength * pulse;
}
