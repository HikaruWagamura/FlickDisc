shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform vec3 base_color : source_color = vec3(0.86, 0.74, 0.50);
uniform vec3 grain_color : source_color = vec3(0.68, 0.52, 0.30);

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 axis = abs(world_normal);
	float along = world_position.z;
	float across = world_position.x;
	if (axis.x > axis.z && axis.x > axis.y) {
		along = world_position.z;
		across = world_position.y;
	} else if (axis.z > axis.x && axis.z > axis.y) {
		along = world_position.x;
		across = world_position.y;
	}
	float grain = 0.5 + 0.5 * sin(across * 46.0 + sin(along * 1.7) * 2.4);
	float streak = smoothstep(0.55, 0.92, grain);
	float fine = 0.5 + 0.5 * sin(along * 9.0);
	vec3 color = mix(base_color, grain_color, streak * 0.55 + fine * 0.06);
	ALBEDO = color;
	ROUGHNESS = 0.68;
	SPECULAR = 0.12;
}
