extends Control

signal start_game(selected_player_scene)

@export var player_1_scene: PackedScene = preload("res://player_plane/player.tscn")
@export var player_2_scene: PackedScene = preload("res://player_plane/player_2.tscn")
@export var player_3_scene: PackedScene = preload("res://player_plane/player_3.tscn")

var selected_player_scene: PackedScene

func _ready() -> void:
	selected_player_scene = player_1_scene

func _on_plane1_button_pressed() -> void:
	selected_player_scene = player_1_scene
	print("Plane 1 selected")

func _on_plane2_button_pressed() -> void:
	selected_player_scene = player_2_scene
	print("Plane 2 selected")

func _on_plane3_button_pressed() -> void:
	selected_player_scene = player_3_scene
	print("Plane 3 selected")

func _on_start_button_pressed() -> void:
	if selected_player_scene == null:
		selected_player_scene = player_1_scene

	emit_signal("start_game", selected_player_scene)
	visible = false


func _on_plane_1_pressed() -> void:
	_on_plane1_button_pressed()


func _on_plane_2_pressed() -> void:
	_on_plane2_button_pressed()


func _on_plane_3_pressed() -> void:
	_on_plane3_button_pressed()
