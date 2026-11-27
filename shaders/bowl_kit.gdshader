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
varying vec3 obj_n;
varying vec3 world_n;

void vertex() {
	obj_pos = VERTEX;
	obj_n = NORMAL;
	world_n = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(obj_n);
	// World X is left-right on the green: the two faces, with the wide
	// equator standing on the grass.
	float side = smoothstep(-seam, seam, normalize(world_n).x);
	vec2 suv = vec2(0.5 + atan(n.x, n.z) / TAU, 0.5 - n.y * 0.5);
	suv *= max(graphic_scale, 0.25);
	vec4 graphic = texture(graphic_tex, suv);
	vec3 paint = color_a.rgb;
	if (look == 0) {
		// Club pack: terrazzo on the coloured half, cream on the other.
		// Object-space split, so the tessellated mesh does not need the
		// C4D multi-material layers Godot cannot load from the cage FBX.
		vec3 colored = mix(color_a.rgb, graphic.rgb, graphic.a * graphic_mix);
		paint = mix(color_b.rgb, colored, side);
	}
	if (look >= 2) {
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
