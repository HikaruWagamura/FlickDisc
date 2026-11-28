shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float power : hint_range(0.0, 1.0) = 0.35;
uniform float along : hint_range(0.0, 1.0) = 0.5;
uniform bool glow_enabled = true;

void fragment() {
	float heat = clamp(power, 0.0, 1.0);
	// The far heads run a little hotter so the line still reads front to back.
	heat = clamp(heat + along * 0.16 * heat, 0.0, 1.0);

	vec3 ice = vec3(0.28, 0.82, 1.0);
	vec3 lilac = vec3(0.78, 0.42, 1.0);
	vec3 pink = vec3(1.0, 0.28, 0.72);
	vec3 hot = vec3(1.0, 0.10, 0.16);
	vec3 dark = vec3(0.52, 0.02, 0.08);

	vec3 colour = mix(ice, lilac, smoothstep(0.00, 0.28, heat));
	colour = mix(colour, pink, smoothstep(0.22, 0.52, heat));
	colour = mix(colour, hot, smoothstep(0.46, 0.78, heat));
	colour = mix(colour, dark, smoothstep(0.72, 1.00, heat));

	float top = smoothstep(0.15, 0.95, clamp(NORMAL.y, 0.0, 1.0));
	vec3 lit = colour * mix(0.62, 1.10, top);

	ALBEDO = lit;
	METALLIC = mix(0.08, 0.16, heat);
	ROUGHNESS = mix(0.42, 0.26, heat);
	SPECULAR = 0.32;

	float emission_strength = glow_enabled ? (0.08 + heat * 0.36) : 0.03;
	EMISSION = colour * emission_strength;
	ALPHA = 1.0;
}
