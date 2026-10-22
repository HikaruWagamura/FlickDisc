shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 0.78);

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv * vec2(1.0, 1.15));
	float alpha = smoothstep(1.05, 0.35, d) * cloud_color.a;
	ALBEDO = cloud_color.rgb;
	ALPHA = alpha;
}
