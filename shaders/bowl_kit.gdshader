shader_type spatial;
render_mode specular_schlick_ggx, cull_back;

uniform vec4 color_a : source_color = vec4(0.82, 0.08, 0.14, 1.0);
uniform vec4 color_b : source_color = vec4(0.96, 0.90, 0.88, 1.0);
uniform int look = 0;
uniform float seam = 0.08;
uniform sampler2D grain_tex : source_color, hint_default_white;
uniform sampler2D graphic_tex : source_color, hint_default_white;
uniform sampler2D normal_tex : hint_normal;
uniform float graphic_mix = 1.0;

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
	vec4 grain = texture(grain_tex, UV);
	float lum = dot(grain.rgb, vec3(0.3, 0.54, 0.16));
	paint *= mix(0.78, 1.16, clamp(lum, 0.0, 1.0));
	if (look >= 2) {
		vec2 suv = vec2(0.5 + atan(n.x, n.z) / TAU, 0.5 - n.y * 0.5);
		vec4 graphic = texture(graphic_tex, suv);
		float mask = graphic.a * graphic_mix;
		if (look == 3) {
			mask *= 1.0 - side;
		}
		paint = mix(paint, graphic.rgb, mask);
	}
	ALBEDO = paint;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 0.55;
	ROUGHNESS = 0.46;
	METALLIC = 0.06;
	SPECULAR = 0.42;
}
