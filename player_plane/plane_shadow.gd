extends Node2D

@export var shadow_width := 52.0
@export var shadow_height := 10.0


func _ready() -> void:
	z_index = -1
	queue_redraw()


func _draw() -> void:
	var points := PackedVector2Array()
	var segments := 20

	for index in segments:
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2(cos(angle) * shadow_width, sin(angle) * shadow_height))

	draw_colored_polygon(points, Color(0.01, 0.02, 0.04, 0.24))
