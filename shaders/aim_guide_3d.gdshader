shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float power : hint_range(0.0, 1.0) = 0.35;
uniform bool glow_enabled = true;

void fragment() {
	float along = clamp(UV.y, 0.0, 1.0);

	vec3 cyan = vec3(0.035, 0.82, 1.0);
	vec3 blue = vec3(0.10, 0.36, 1.0);
	vec3 violet = vec3(0.55, 0.16, 0.98);
	vec3 ember = vec3(1.0, 0.20, 0.055);

	vec3 powered_tip = mix(blue, ember, smoothstep(0.12, 1.0, power));
	vec3 middle = mix(violet, powered_tip, smoothstep(0.30, 0.95, power));
	vec3 longitudinal = mix(cyan, middle, smoothstep(0.02, 0.94, along));

	float side_light = 0.78 + 0.22 * abs(NORMAL.y);
	float edge = smoothstep(0.0, 0.20, abs(UV.x - 0.5));
	float sheen = pow(max(0.0, 1.0 - abs(UV.x - 0.5) * 2.0), 5.0);
	vec3 surface_colour = longitudinal * side_light;
	surface_colour += vec3(0.30, 0.42, 0.55) * sheen * 0.18;
	surface_colour *= mix(0.82, 1.0, edge);

	ALBEDO = surface_colour;
	METALLIC = 0.24;
	ROUGHNESS = mix(0.32, 0.20, power);
	SPECULAR = 0.72;

	float emission_strength = glow_enabled ? (0.16 + power * 0.85) : 0.08;
	EMISSION = longitudinal * emission_strength;

	ALPHA = 0.96;
}
