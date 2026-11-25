class_name BiasChip
extends Control

## One bias on the right-hand rail. The portrait is the bowl you are
## about to send, and the curve under it is how hard that stone hooks.

signal picked(index: int)

const NAMES := ["NARROW", "MEDIUM", "WIDE", "HOOK"]
const HOOK := [0.22, 0.42, 0.68, 0.95]
const FONT := preload("res://assets/fonts/Inter-Bold.ttf")

var index := 0
var selected := false
var portrait: Texture2D
var team := 0


func _ready() -> void:
	custom_minimum_size = Vector2(72.0, 96.0)
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
	var centre := Vector2(size.x * 0.5, 34.0)
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.006) if selected else 0.0
	var radius := 28.0 + pulse * 2.0 if selected else 25.0
	draw_circle(centre + Vector2(0.0, 3.0), radius + 2.0, Color(0.12, 0.02, 0.18, 0.55))
	if portrait != null:
		var box := Rect2(centre - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
		draw_texture_rect(portrait, box, false)
	else:
		var body := Color(0.82, 0.08, 0.14) if team % 2 == 0 else Color(0.14, 0.34, 0.88)
		draw_circle(centre, radius, body)
	var ring := Color("#5CFFF2") if selected else Color(1.0, 0.85, 0.95, 0.35)
	draw_arc(centre, radius + 2.0, 0.0, TAU, 48, ring, 3.0 if selected else 1.4, true)
	if selected:
		draw_arc(centre, radius + 6.0, 0.0, TAU, 48, Color(1.0, 0.18, 0.54, 0.45 + pulse * 0.4), 2.0, true)
	_draw_hook(centre + Vector2(0.0, radius + 12.0))
	if selected:
		var label: String = NAMES[index % NAMES.size()]
		var wide := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var badge := Rect2(centre.x - wide * 0.5 - 8.0, size.y - 20.0, wide + 16.0, 18.0)
		draw_rect(badge, Color("#FF2E8A"), true)
		draw_string(FONT, Vector2(badge.position.x + 8.0, badge.position.y + 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#FFF6FF"))


func _draw_hook(origin: Vector2) -> void:
	var bend: float = float(HOOK[index % HOOK.size()])
	var color := Color("#FF2E8A") if selected else Color(0.75, 0.85, 1.0, 0.75)
	var points := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		var along := lerpf(-12.0, 12.0, t)
		var side: float = -bend * 11.0 * sin(t * PI)
		points.append(origin + Vector2(along, side))
	draw_polyline(points, color, 2.8 if selected else 1.7, true)
