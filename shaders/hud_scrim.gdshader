shader_type canvas_item;

void fragment() {
	float top = smoothstep(0.085, 0.0, UV.y);
	float alpha = top * 0.55;
	COLOR = vec4(0.015, 0.04, 0.07, alpha);
}
