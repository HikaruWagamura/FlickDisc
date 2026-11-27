shader_type spatial;
render_mode specular_schlick_ggx, cull_back;

uniform vec4 color_a : source_color = vec4(0.82, 0.08, 0.14, 1.0);
uniform vec4 color_b : source_color = vec4(0.96, 0.90, 0.88, 1.0);
uniform int look = 0;
uniform float seam = 0.02;
uniform sampler2D graphic_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D graphic_tex_b : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float graphic_mix = 1.0;
uniform float graphic_scale = 1.0;
uniform float roughness_val = 0.42;
uniform float metallic_val = 0.04;
// Pack mesh space: the short pole through the two grip faces.
uniform vec3 pole_axis = vec3(1.0, 0.0, 0.0);
uniform vec3 mesh_center = vec3(0.0);
uniform float pole_half = 1.0;
uniform vec3 face_up = vec3(0.0, 1.0, 0.0);

varying vec3 obj_pos;
varying vec3 obj_n;

void vertex() {
	obj_pos = VERTEX;
	obj_n = NORMAL;
}

vec2 _face_uv(vec3 radial, vec3 tanv, vec3 bitv, float span) {
	vec2 uv = vec2(dot(radial, tanv), -dot(radial, bitv)) / max(span, 0.001);
	return uv * 0.5 + vec2(0.5);
}

vec2 _wrap_uv(vec3 radial, float along_n, vec3 tanv, vec3 bitv) {
	float u = atan(dot(radial, bitv), dot(radial, tanv)) / TAU + 0.5;
	float v = clamp(0.5 - along_n * 0.5, 0.0, 1.0);
	return vec2(u, v) * max(graphic_scale, 0.25);
}

float _circle_mask(vec2 uv) {
	float r = length(uv * 2.0 - vec2(1.0));
	return 1.0 - smoothstep(0.90, 1.0, r);
}

void fragment() {
	vec3 n = normalize(obj_n);
	vec3 pole = normalize(pole_axis);
	// True plane through the mesh centre, halfway between the two
	// modelled hand-groove faces. No vertex displace — that warped the
	// seam so it looked centred at the top and hit one groove at the bottom.
	vec3 rel = obj_pos - mesh_center;
	float along_n = dot(rel, pole) / max(pole_half, 0.001);
	float side = smoothstep(-seam, seam, along_n);
	vec3 radial = rel - pole * (along_n * pole_half);
	vec3 up = face_up;
	if (length(up) < 0.001) {
		up = vec3(0.0, 1.0, 0.0);
	}
	if (abs(dot(normalize(up), pole)) > 0.92) {
		up = vec3(0.0, 0.0, 1.0);
	}
	vec3 tanv = normalize(cross(up, pole));
	vec3 bitv = cross(pole, tanv);
	vec2 suv = UV * max(graphic_scale, 0.25);
	vec4 graphic = texture(graphic_tex, suv);
	vec3 paint = color_a.rgb;
	if (look == 0) {
		vec3 colored = mix(color_a.rgb, graphic.rgb, graphic.a * graphic_mix);
		paint = mix(color_b.rgb, colored, side);
	}
	if (look == 1) {
		paint = color_a.rgb;
	}
	if (look == 2) {
		vec2 wuv = _wrap_uv(radial, along_n, tanv, bitv);
		vec4 wrap = texture(graphic_tex, wuv);
		paint = mix(color_a.rgb, wrap.rgb, wrap.a * graphic_mix);
	}
	if (look >= 3) {
		float span = pole_half * 0.92;
		vec2 fuv = _face_uv(radial, tanv, bitv, span);
		float disc = _circle_mask(fuv);
		vec4 face_a = texture(graphic_tex, fuv);
		vec4 face_b = texture(graphic_tex_b, fuv);
		if (look == 3) {
			paint = mix(paint, face_a.rgb, face_a.a * disc * graphic_mix * (1.0 - side));
		}
		if (look == 4) {
			paint = mix(paint, face_a.rgb, face_a.a * disc * graphic_mix * side);
		}
		if (look == 5) {
			paint = mix(paint, face_a.rgb, face_a.a * disc * graphic_mix * (1.0 - side));
			paint = mix(paint, face_b.rgb, face_b.a * disc * graphic_mix * side);
		}
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
