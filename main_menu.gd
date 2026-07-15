extends Control

signal start_game(selected_player_scene, selected_map_id, pilot_name)

@export var player_1_scene: PackedScene = preload("res://player_plane/player.tscn")
@export var player_2_scene: PackedScene = preload("res://player_plane/player_2.tscn")
@export var player_3_scene: PackedScene = preload("res://player_plane/player_3.tscn")

@onready var plane_preview: Sprite2D = $Panel/PreviewPanel/PlanePreview
@onready var selected_plane_label: Label = $Panel/PreviewPanel/SelectedPlaneLabel
@onready var speed_bar: ProgressBar = $Panel/PreviewPanel/Stats/Speed/Bar
@onready var speed_value: Label = $Panel/PreviewPanel/Stats/Speed/Value
@onready var fire_rate_bar: ProgressBar = $Panel/PreviewPanel/Stats/FireRate/Bar
@onready var fire_rate_value: Label = $Panel/PreviewPanel/Stats/FireRate/Value
@onready var control_bar: ProgressBar = $Panel/PreviewPanel/Stats/Control/Bar
@onready var control_value: Label = $Panel/PreviewPanel/Stats/Control/Value
@onready var plane_1_button: Button = $Panel/CharacterSelect/plane1
@onready var plane_2_button: Button = $Panel/CharacterSelect/plane2
@onready var plane_3_button: Button = $Panel/CharacterSelect/plane3
@onready var map_preview: TextureRect = $Panel/MapPanel/MapPreview
@onready var selected_map_label: Label = $Panel/MapPanel/SelectedMapLabel
@onready var ocean_button: Button = $Panel/MapPanel/MapButtons/Ocean
@onready var grassland_button: Button = $Panel/MapPanel/MapButtons/Grassland
@onready var desert_button: Button = $Panel/MapPanel/MapButtons/Desert
@onready var pilot_name_input: LineEdit = $Panel/PilotRow/PilotName
@onready var leaderboard_overlay: Panel = $Panel/LeaderboardOverlay
@onready var leaderboard_entries: Label = $Panel/LeaderboardOverlay/Entries
@onready var controls_overlay: Panel = $Panel/ControlsOverlay

const PLANE_1_TEXTURE: Texture2D = preload("res://assets/plane1_512.png")
const PLANE_2_TEXTURE: Texture2D = preload("res://assets/plane2_512.png")
const PLANE_3_TEXTURE: Texture2D = preload("res://assets/plane3_512.png")
const PLANE_1_PREVIEW_SCALE := 0.34
const PLANE_2_PREVIEW_SCALE := 0.282
const PLANE_3_PREVIEW_SCALE := 0.30
const PLANE_1_PREVIEW_PROPELLERS := [Vector2(94, 48)]
const PLANE_2_PREVIEW_PROPELLERS := [Vector2(94, 43)]
const PLANE_3_PREVIEW_PROPELLERS := [Vector2(73, 61), Vector2(115, 61)]
const PROPELLER_SCRIPT := preload("res://player_plane/propeller.gd")
const SELECTED_BUTTON_COLOR := Color(1.0, 0.83, 0.35)
const DEFAULT_BUTTON_COLOR := Color.WHITE
const OCEAN_TEXTURE: Texture2D = preload("res://assets/ocean.png")
const GRASSLAND_TEXTURE: Texture2D = preload("res://assets/greenland_seamless.png")
const DESERT_TEXTURE: Texture2D = preload("res://assets/desertland_seamless.png")

var selected_player_scene: PackedScene
var selected_map_id := "ocean"
var selected_plane_name := "PLANE 1"
var preview_propellers: Array[Node2D] = []

func _ready() -> void:
	_select_player(player_1_scene, PLANE_1_TEXTURE, PLANE_1_PREVIEW_SCALE, PLANE_1_PREVIEW_PROPELLERS, "PLANE 1", plane_1_button)
	_select_map("ocean", "OCEAN", OCEAN_TEXTURE, ocean_button)
	pilot_name_input.text = GameData.pilot_name
	leaderboard_overlay.visible = false
	controls_overlay.visible = false

func _on_plane1_button_pressed() -> void:
	_select_player(player_1_scene, PLANE_1_TEXTURE, PLANE_1_PREVIEW_SCALE, PLANE_1_PREVIEW_PROPELLERS, "PLANE 1", plane_1_button)
	print("Plane 1 selected")

func _on_plane2_button_pressed() -> void:
	_select_player(player_2_scene, PLANE_2_TEXTURE, PLANE_2_PREVIEW_SCALE, PLANE_2_PREVIEW_PROPELLERS, "PLANE 2", plane_2_button)
	print("Plane 2 selected")

func _on_plane3_button_pressed() -> void:
	_select_player(player_3_scene, PLANE_3_TEXTURE, PLANE_3_PREVIEW_SCALE, PLANE_3_PREVIEW_PROPELLERS, "PLANE 3", plane_3_button)
	print("Plane 3 selected")

func _select_player(
	player_scene: PackedScene,
	preview_texture: Texture2D,
	preview_scale: float,
	preview_propeller_positions: Array,
	plane_name: String,
	selected_button: Button
) -> void:
	selected_player_scene = player_scene
	selected_plane_name = plane_name
	plane_preview.texture = preview_texture
	plane_preview.scale = Vector2.ONE * preview_scale
	_refresh_preview_propellers(preview_propeller_positions)

	var plane = player_scene.instantiate()
	var shots_per_second: float = 1.0 / plane.rate_of_fire

	selected_plane_label.text = "%s  |  %d LIVES" % [plane_name, plane.max_lives]
	speed_bar.value = plane.speed
	speed_value.text = str(plane.speed)
	fire_rate_bar.value = shots_per_second
	fire_rate_value.text = "%.1f/s" % shots_per_second
	control_bar.value = plane.control_rating
	control_value.text = "%d/5" % plane.control_rating

	plane.free()

	for button in [plane_1_button, plane_2_button, plane_3_button]:
		button.modulate = DEFAULT_BUTTON_COLOR

	selected_button.modulate = SELECTED_BUTTON_COLOR


func _refresh_preview_propellers(propeller_positions: Array) -> void:
	for propeller in preview_propellers:
		propeller.free()

	preview_propellers.clear()

	for propeller_position in propeller_positions:
		var propeller := Node2D.new()
		propeller.set_script(PROPELLER_SCRIPT)
		propeller.position = propeller_position
		propeller.blade_length = 12.0
		$Panel/PreviewPanel.add_child(propeller)
		preview_propellers.append(propeller)


func _select_map(
	map_id: String,
	map_name: String,
	map_texture: Texture2D,
	selected_button: Button
) -> void:
	selected_map_id = map_id
	selected_map_label.text = map_name
	map_preview.texture = map_texture

	for button in [ocean_button, grassland_button, desert_button]:
		button.modulate = DEFAULT_BUTTON_COLOR

	selected_button.modulate = SELECTED_BUTTON_COLOR

func _on_start_button_pressed() -> void:
	if selected_player_scene == null:
		selected_player_scene = player_1_scene

	var pilot_name := GameData.set_pilot_name(pilot_name_input.text)
	GameData.set_loadout(
		selected_player_scene,
		selected_plane_name,
		selected_map_id
	)
	emit_signal("start_game", selected_player_scene, selected_map_id, pilot_name)
	visible = false


func _on_plane_1_pressed() -> void:
	_on_plane1_button_pressed()


func _on_plane_2_pressed() -> void:
	_on_plane2_button_pressed()


func _on_plane_3_pressed() -> void:
	_on_plane3_button_pressed()


func _on_ocean_pressed() -> void:
	_select_map("ocean", "OCEAN", OCEAN_TEXTURE, ocean_button)


func _on_grassland_pressed() -> void:
	_select_map("grassland", "GRASSLAND", GRASSLAND_TEXTURE, grassland_button)


func _on_desert_pressed() -> void:
	_select_map("desert", "DESERT", DESERT_TEXTURE, desert_button)


func _on_leaderboard_pressed() -> void:
	leaderboard_entries.text = GameData.format_leaderboard()
	leaderboard_overlay.visible = true


func _on_close_leaderboard_pressed() -> void:
	leaderboard_overlay.visible = false


func _on_controls_pressed() -> void:
	for propeller in preview_propellers:
		propeller.visible = false
	controls_overlay.visible = true


func _on_close_controls_pressed() -> void:
	controls_overlay.visible = false
	for propeller in preview_propellers:
		propeller.visible = true
