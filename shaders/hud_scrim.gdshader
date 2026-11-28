shader_type canvas_item;

void fragment() {
	float top = smoothstep(0.085, 0.0, UV.y);
	float alpha = top * 0.55;
	COLOR = vec4(0.16, 0.03, 0.22, alpha);
}
