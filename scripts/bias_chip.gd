class_name BiasChip
extends Control

## One bias bowl under the power bar. The name sits on the stone so you
## can tell NARROW from HOOK without opening a selected badge.

signal picked(index: int)

const NAMES := ["STD", "WIDE", "EXTRA", "MAX"]
const HOOK := [0.18, 0.44, 0.72, 1.0]
const FONT := preload("res://assets/fonts/Inter-Bold.ttf")

var index := 0
var selected := false
var portrait: Texture2D
var team := 0


func _ready() -> void:
	custom_minimum_size = Vector2(64.0, 70.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func _process(_delta: float) -> void:
	if selected:
		queue_redraw()


func set_chip(bias: int, team_index: int, tex: Texture2D, on: bool) -> void:
	index = bias
	team = team_index
	portrait = tex
	selected = on
	queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(index)
		accept_event()


func _draw() -> void:
	var centre := Vector2(size.x * 0.5, 28.0)
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.006) if selected else 0.0
	var radius := 24.0 + pulse * 1.6 if selected else 22.0
	draw_circle(centre + Vector2(0.0, 2.0), radius + 1.5, Color(0.10, 0.02, 0.16, 0.50))
	if portrait != null:
		var box := Rect2(centre - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
		draw_texture_rect(portrait, box, false)
	else:
		var body := Color(0.82, 0.08, 0.14) if team % 2 == 0 else Color(0.14, 0.34, 0.88)
		draw_circle(centre, radius, body)
	var ring := Color("#5CFFF2") if selected else Color(1.0, 0.85, 0.95, 0.32)
	draw_arc(centre, radius + 1.6, 0.0, TAU, 40, ring, 2.6 if selected else 1.2, true)
	if selected:
		draw_arc(centre, radius + 5.0, 0.0, TAU, 40, Color(1.0, 0.18, 0.54, 0.42 + pulse * 0.35), 1.8, true)
	var label: String = NAMES[index % NAMES.size()]
	var font_size := 8 if label.length() > 4 else 9
	var wide := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ink := Color("#FFF6FF") if selected else Color(0.96, 0.98, 1.0, 0.92)
	var outline := Color(0.12, 0.02, 0.10, 0.88)
	var text_at := Vector2(centre.x - wide * 0.5, centre.y + 4.0)
	draw_string_outline(FONT, text_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, outline)
	draw_string(FONT, text_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	var num := str(index + 1)
	var num_wide := FONT.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var num_at := Vector2(centre.x - num_wide * 0.5, 11.0)
	draw_string_outline(FONT, num_at, num, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, outline)
	draw_string(FONT, num_at, num, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)
	_draw_hook(Vector2(centre.x, centre.y + radius + 8.0))


func _draw_hook(origin: Vector2) -> void:
	var bend: float = float(HOOK[index % HOOK.size()])
	var color := Color("#FF2E8A") if selected else Color(0.75, 0.85, 1.0, 0.7)
	var points := PackedVector2Array()
	for i in 7:
		var t := float(i) / 6.0
		var along := lerpf(-9.0, 9.0, t)
		var side: float = -bend * 7.0 * sin(t * PI)
		points.append(origin + Vector2(along, side))
	draw_polyline(points, color, 2.2 if selected else 1.4, true)
