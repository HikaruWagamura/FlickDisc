shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 stripe_a : source_color = vec3(0.486, 0.690, 0.251);
uniform vec3 stripe_b : source_color = vec3(0.345, 0.545, 0.176);
uniform float stripe_width = 0.48;
uniform float half_width = 2.9;
uniform float depth_fade = 0.16;

varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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
	float band = abs(fract(world_position.x / stripe_width) - 0.5) * 2.0;
	float stripe = smoothstep(0.12, 0.88, band);
	vec3 color = mix(stripe_b, stripe_a, stripe);
	float patch = value_noise(world_position.xz * 0.33);
	float grain = value_noise(world_position.xz * 5.5);
	color *= 0.94 + patch * 0.08 + grain * 0.03;
	float edge = smoothstep(half_width - 0.7, half_width - 0.02, abs(world_position.x));
	color = mix(color, color * vec3(0.80, 0.88, 0.74), edge * 0.65);
	float depth = clamp((-world_position.z) / 40.0, 0.0, 1.0);
	color = mix(color, color * vec3(0.84, 0.92, 0.80), depth * depth_fade);
	ALBEDO = color;
	ROUGHNESS = 0.92;
	SPECULAR = 0.06;
	METALLIC = 0.0;
}
