class_name BiasChip
extends Control

## One bias on the rail. The portrait is the pack bowl; the curve under
## it is how hard that stone hooks.

signal picked(index: int)

const NAMES := ["NARROW", "MEDIUM", "WIDE", "HOOK"]
const HOOK := [0.22, 0.42, 0.68, 0.95]

var index := 0
var selected := false
var portrait: Texture2D
var team := 0


func _ready() -> void:
	custom_minimum_size = Vector2(72.0, 94.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


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
	var centre := Vector2(size.x * 0.5, 36.0)
	var radius := 30.0 if selected else 27.0
	draw_circle(centre + Vector2(0.0, 3.0), radius + 1.0, Color(0.0, 0.02, 0.01, 0.42))
	if portrait != null:
		var box := Rect2(centre - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
		draw_texture_rect(portrait, box, false)
	else:
		_draw_fallback(centre, radius)
	var ring := Color("#ffe9a4") if selected else Color(1.0, 0.95, 0.82, 0.28)
	var ring_w := 3.2 if selected else 1.4
	draw_arc(centre, radius + 1.5, 0.0, TAU, 42, ring, ring_w, true)
	if selected:
		draw_arc(centre, radius + 5.0, 0.0, TAU, 42, Color(0.95, 0.74, 0.34, 0.55), 1.4, true)
	_draw_hook(centre + Vector2(0.0, radius + 10.0))
	if selected:
		var font := ThemeDB.fallback_font
		var label: String = NAMES[index % NAMES.size()]
		var wide := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(
			font,
			Vector2(centre.x - wide * 0.5, size.y - 6.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color("#ffe9a4")
		)


func _draw_hook(origin: Vector2) -> void:
	var bend: float = float(HOOK[index % HOOK.size()])
	var color := Color("#f3bd56") if selected else Color(0.92, 0.86, 0.7, 0.7)
	var points := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		var along := lerpf(-11.0, 11.0, t)
		var side: float = -bend * 10.0 * sin(t * PI)
		points.append(origin + Vector2(along, side))
	draw_polyline(points, color, 2.4 if selected else 1.6, true)


func _draw_fallback(centre: Vector2, radius: float) -> void:
	var body := Color(0.72, 0.12, 0.14) if team == 0 else Color(0.12, 0.28, 0.72)
	draw_circle(centre, radius, body)
	draw_arc(centre, radius * 0.72, 0.0, TAU, 28, Color(0.94, 0.91, 0.84, 0.85), 2.0, true)
	var pip := centre + Vector2(radius * (0.18 + 0.16 * float(index)), -radius * 0.08)
	draw_circle(pip, radius * 0.22, Color(0.96, 0.94, 0.9))
