shader_type spatial;
render_mode specular_schlick_ggx, cull_back;

uniform vec4 color_a : source_color = vec4(0.82, 0.08, 0.14, 1.0);
uniform vec4 color_b : source_color = vec4(0.96, 0.90, 0.88, 1.0);
uniform int look = 0;
uniform float seam = 0.02;
uniform sampler2D graphic_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float graphic_mix = 1.0;
uniform float graphic_scale = 1.0;
uniform float roughness_val = 0.42;
uniform float metallic_val = 0.04;
// Pack mesh space: the short pole through the two grip faces.
uniform vec3 pole_axis = vec3(1.0, 0.0, 0.0);
uniform vec3 mesh_center = vec3(0.0);
uniform float pole_half = 1.0;

varying vec3 obj_pos;
varying vec3 obj_n;

void vertex() {
	obj_pos = VERTEX;
	obj_n = NORMAL;
}

void fragment() {
	vec3 n = normalize(obj_n);
	vec3 pole = normalize(pole_axis);
	// True plane through the mesh centre, halfway between the two
	// modelled hand-groove faces. No vertex displace — that warped the
	// seam so it looked centred at the top and hit one groove at the bottom.
	float along_n = dot(obj_pos - mesh_center, pole) / max(pole_half, 0.001);
	float side = smoothstep(-seam, seam, along_n);
	vec2 suv = UV * max(graphic_scale, 0.25);
	vec4 graphic = texture(graphic_tex, suv);
	vec3 paint = color_a.rgb;
	if (look == 0) {
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
	// Shade the mesh's own creases so the modelled grips read, without
	// drawing a second set of rings on top of them.
	float crease = clamp(length(fwidth(n)) * 2.8, 0.0, 0.35);
	paint *= 1.0 - crease;
	ALBEDO = paint;
	ROUGHNESS = roughness_val;
	METALLIC = metallic_val;
	SPECULAR = 0.48;
}
