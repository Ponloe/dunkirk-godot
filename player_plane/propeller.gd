extends Node2D

@export var blade_length := 13.0
@export var blade_width := 3.0
@export var spin_speed := 18.0


func _ready() -> void:
	z_index = 2
	queue_redraw()


func _process(delta: float) -> void:
	rotation += spin_speed * delta


func _draw() -> void:
	var blade_color := Color(0.08, 0.1, 0.12, 0.78)
	var highlight_color := Color(0.76, 0.82, 0.84, 0.58)

	draw_line(
		Vector2(-blade_length, 0),
		Vector2(blade_length, 0),
		blade_color,
		blade_width,
		false
	)
	draw_line(
		Vector2(0, -blade_length),
		Vector2(0, blade_length),
		blade_color,
		blade_width,
		false
	)
	draw_line(
		Vector2(-blade_length * 0.72, 0),
		Vector2(blade_length * 0.72, 0),
		highlight_color,
		1.0,
		false
	)
	draw_circle(Vector2.ZERO, blade_width, Color(0.95, 0.68, 0.12, 1.0))
