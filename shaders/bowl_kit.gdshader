shader_type spatial;
render_mode specular_schlick_ggx, cull_back;

uniform vec4 color_a : source_color = vec4(0.82, 0.08, 0.14, 1.0);
uniform vec4 color_b : source_color = vec4(0.96, 0.90, 0.88, 1.0);
uniform int look = 0;
uniform float seam = 0.08;
uniform sampler2D graphic_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float graphic_mix = 1.0;
uniform float graphic_scale = 1.0;
uniform float roughness_val = 0.42;
uniform float metallic_val = 0.04;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 n = normalize(obj_pos);
	float side = smoothstep(-seam, seam, n.x);
	vec3 paint = color_a.rgb;
	if (look == 0) {
		paint = mix(color_a.rgb, color_b.rgb, side);
	}
	if (look >= 2) {
		vec2 suv = vec2(0.5 + atan(n.x, n.z) / TAU, 0.5 - n.y * 0.5);
		suv *= max(graphic_scale, 0.25);
		vec4 graphic = texture(graphic_tex, suv);
		float mask = graphic.a * graphic_mix;
		if (look == 3) {
			mask *= 1.0 - side;
		}
		paint = mix(paint, graphic.rgb, mask);
	}
	ALBEDO = paint;
	ROUGHNESS = roughness_val;
	METALLIC = metallic_val;
	SPECULAR = 0.48;
}
