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
// Pack mesh space: the short pole through the two grip faces.
uniform vec3 pole_axis = vec3(1.0, 0.0, 0.0);
uniform vec3 mesh_center = vec3(0.0);
uniform float pole_half = 1.0;
// Inner hand-groove as a fraction of pole_half. Same on both faces so
// the two rings stay parallel and the equator is exactly between them.
uniform float groove_inner = 0.55;
uniform float groove_width = 0.032;

varying vec3 obj_pos;
varying vec3 obj_n;
varying float along_n;
varying float groove_v;

float groove_mask(float a) {
	float inner = 1.0 - smoothstep(0.0, groove_width, abs(a - groove_inner));
	// Second face ring, also mirrored, so both sides stay equidistant.
	float outer = 1.0 - smoothstep(0.0, groove_width, abs(a - (groove_inner + 0.17)));
	return max(inner, outer * 0.92);
}

void vertex() {
	obj_pos = VERTEX;
	obj_n = NORMAL;
	vec3 pole = normalize(pole_axis);
	along_n = dot(VERTEX - mesh_center, pole) / max(pole_half, 0.001);
	groove_v = groove_mask(abs(along_n));
	// Push the ring into the surface so it reads as a hand groove, not a
	// painted stripe. Mesh units: ~0.55 is a few millimetres once seated.
	VERTEX += NORMAL * (-0.58 * groove_v);
}

void fragment() {
	vec3 n = normalize(obj_n);
	// Split on position along the pole, not the surface normal. On a
	// flattened bowl those are different, and the normal split misses
	// the midplane between the two hand grooves.
	float side = smoothstep(-seam, seam, along_n);
	vec2 suv = vec2(0.5 + atan(n.x, n.z) / TAU, 0.5 - n.y * 0.5);
	suv *= max(graphic_scale, 0.25);
	vec4 graphic = texture(graphic_tex, suv);
	vec3 paint = color_a.rgb;
	if (look == 0) {
		vec3 colored = mix(color_a.rgb, graphic.rgb, graphic.a * graphic_mix);
		paint = mix(color_b.rgb, colored, side);
		// Faint dimples on the cream face so both grips show, not just red.
		float lum = dot(graphic.rgb, vec3(0.33, 0.33, 0.34));
		float dim = mix(0.62, 1.0, clamp(lum, 0.0, 1.0));
		paint = mix(paint, paint * dim, (1.0 - side) * graphic.a * graphic_mix * 0.5);
	}
	if (look >= 2) {
		float mask = graphic.a * graphic_mix;
		if (look == 3) {
			mask *= 1.0 - side;
		}
		paint = mix(paint, graphic.rgb, mask);
	}
	// Cream rings on the coloured face (the old square-of-aces look);
	// a darker indent on the cream face so the matching groove is visible.
	vec3 ring_col = mix(vec3(0.50, 0.46, 0.44), color_b.rgb, side);
	paint = mix(paint, ring_col, groove_v * 0.94);
	ALBEDO = paint;
	ROUGHNESS = mix(roughness_val, 0.30, groove_v);
	METALLIC = metallic_val;
	SPECULAR = 0.48;
}
