shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform vec3 base_color : source_color = vec3(0.78, 0.68, 0.48);
uniform vec3 shade_color : source_color = vec3(0.62, 0.52, 0.36);

varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 24613.7);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = value_noise(world_position.xz * 1.6);
	float fine = value_noise(world_position.xz * 7.0);
	vec3 color = mix(shade_color, base_color, n);
	color *= 0.94 + fine * 0.08;
	ALBEDO = color;
	ROUGHNESS = 0.92;
	SPECULAR = 0.05;
}
