shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled;

uniform vec4 color_a : source_color = vec4(1.0, 0.24, 0.6, 1.0);
uniform vec4 color_b : source_color = vec4(0.96, 0.90, 0.88, 1.0);
uniform int look = 0;
uniform float seam = 0.08;
uniform sampler2D graphic_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float graphic_mix = 1.0;
uniform float graphic_scale = 1.6;
uniform float span = 0.22;
uniform int face = 0;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	float across = obj_pos.x;
	if (face == 2) {
		across = obj_pos.z;
	}
	float side = smoothstep(-seam, seam, across);
	vec3 paint = color_a.rgb;
	if (look == 0) {
		paint = mix(color_a.rgb, color_b.rgb, side);
	}
	vec2 suv = vec2(
		0.5 + obj_pos.x / max(span, 0.001),
		0.5 + obj_pos.z / max(span, 0.001)
	);
	if (face == 1) {
		suv = vec2(
			0.5 + obj_pos.x / max(span, 0.001),
			0.5 + obj_pos.y / max(span, 0.001)
		);
	} else if (face == 2) {
		suv = vec2(
			0.5 + obj_pos.z / max(span, 0.001),
			0.5 + obj_pos.y / max(span, 0.001)
		);
	}
	if (look >= 2) {
		vec4 graphic = texture(graphic_tex, suv * max(graphic_scale, 0.25));
		float mask = graphic.a * graphic_mix;
		if (look == 3) {
			mask *= 1.0 - side;
		}
		paint = mix(paint, graphic.rgb, mask);
	}
	ALBEDO = paint;
	ROUGHNESS = 0.34;
	METALLIC = 0.08;
	SPECULAR = 0.48;
}
