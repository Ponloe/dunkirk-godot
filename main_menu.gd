extends Control

signal start_game(selected_player_scene, selected_map_id, pilot_name)
signal map_selected(map_id)

@export var player_1_scene: PackedScene = preload("res://player_plane/player.tscn")
@export var player_2_scene: PackedScene = preload("res://player_plane/player_2.tscn")
@export var player_3_scene: PackedScene = preload("res://player_plane/player_3.tscn")
@export var player_4_scene: PackedScene = preload("res://player_plane/player_4.tscn")

@onready var plane_preview: Sprite2D = $Panel/PreviewPanel/PlanePreview
@onready var selected_plane_label: Label = $Panel/PreviewPanel/SelectedPlaneLabel
@onready var speed_bar: ProgressBar = $Panel/PreviewPanel/Stats/Speed/Bar
@onready var speed_value: Label = $Panel/PreviewPanel/Stats/Speed/Value
@onready var fire_rate_bar: ProgressBar = $Panel/PreviewPanel/Stats/FireRate/Bar
@onready var fire_rate_value: Label = $Panel/PreviewPanel/Stats/FireRate/Value
@onready var control_bar: ProgressBar = $Panel/PreviewPanel/Stats/Control/Bar
@onready var control_value: Label = $Panel/PreviewPanel/Stats/Control/Value
@onready var stats: VBoxContainer = $Panel/PreviewPanel/Stats
@onready var plane_1_button: Button = $Panel/CharacterSelect/plane1
@onready var plane_2_button: Button = $Panel/CharacterSelect/plane2
@onready var plane_3_button: Button = $Panel/CharacterSelect/plane3
@onready var plane_4_button: Button = $Panel/CharacterSelect/plane4
@onready var lock_status: Label = $Panel/PreviewPanel/LockStatus
@onready var start_button: Button = $Panel/StartButton
@onready var map_preview: TextureRect = $Panel/MapPanel/MapPreview
@onready var selected_map_label: Label = $Panel/MapPanel/SelectedMapLabel
@onready var ocean_button: Button = $Panel/MapPanel/MapButtons/Ocean
@onready var grassland_button: Button = $Panel/MapPanel/MapButtons/Grassland
@onready var desert_button: Button = $Panel/MapPanel/MapButtons/Desert
@onready var pilot_name_input: LineEdit = $Panel/PilotRow/PilotName
@onready var leaderboard_overlay: Panel = $Panel/LeaderboardOverlay
@onready var leaderboard_modal_blocker: ColorRect = $Panel/LeaderboardModalBlocker
@onready var leaderboard_entries: VBoxContainer = $Panel/LeaderboardOverlay/Entries
@onready var controls_overlay: Panel = $Panel/ControlsOverlay
@onready var controls_modal_blocker: ColorRect = $Panel/ControlsModalBlocker
@onready var audio_overlay: Panel = $Panel/AudioOverlay
@onready var audio_modal_blocker: ColorRect = $Panel/AudioModalBlocker
@onready var music_slider: HSlider = $Panel/AudioOverlay/MusicSlider
@onready var sfx_slider: HSlider = $Panel/AudioOverlay/SFXSlider
@onready var music_value: Label = $Panel/AudioOverlay/MusicValue
@onready var sfx_value: Label = $Panel/AudioOverlay/SFXValue

const PLANE_1_TEXTURE: Texture2D = preload("res://assets/plane1_512.png")
const PLANE_2_TEXTURE: Texture2D = preload("res://assets/plane2_512.png")
const PLANE_3_TEXTURE: Texture2D = preload("res://assets/plane3_512.png")
const PLANE_4_TEXTURE: Texture2D = preload("res://assets/plane4_512.png")
const PLANE_1_PREVIEW_SCALE := 0.34
const PLANE_2_PREVIEW_SCALE := 0.282
const PLANE_3_PREVIEW_SCALE := 0.30
const PLANE_4_PREVIEW_SCALE := 0.25
const PLANE_1_PREVIEW_PROPELLERS := [Vector2(94, 48)]
const PLANE_2_PREVIEW_PROPELLERS := [Vector2(94, 43)]
const PLANE_3_PREVIEW_PROPELLERS := [Vector2(73, 61), Vector2(115, 61)]
const PLANE_4_PREVIEW_PROPELLERS := [Vector2(70, 64), Vector2(118, 64)]
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
	_restore_saved_plane()
	_restore_saved_map()
	pilot_name_input.text = GameData.pilot_name
	leaderboard_overlay.visible = false
	leaderboard_modal_blocker.visible = false
	controls_overlay.visible = false
	controls_modal_blocker.visible = false
	audio_overlay.visible = false
	audio_modal_blocker.visible = false
	music_slider.set_value_no_signal(GameData.music_volume * 100.0)
	sfx_slider.set_value_no_signal(GameData.sfx_volume * 100.0)
	_update_audio_labels()
	_refresh_secret_plane_state()

func _on_plane1_button_pressed() -> void:
	_select_player(player_1_scene, PLANE_1_TEXTURE, PLANE_1_PREVIEW_SCALE, PLANE_1_PREVIEW_PROPELLERS, "PLANE 1", plane_1_button)

func _on_plane2_button_pressed() -> void:
	_select_player(player_2_scene, PLANE_2_TEXTURE, PLANE_2_PREVIEW_SCALE, PLANE_2_PREVIEW_PROPELLERS, "PLANE 2", plane_2_button)

func _on_plane3_button_pressed() -> void:
	_select_player(player_3_scene, PLANE_3_TEXTURE, PLANE_3_PREVIEW_SCALE, PLANE_3_PREVIEW_PROPELLERS, "PLANE 3", plane_3_button)


func _on_plane4_button_pressed() -> void:
	if not GameData.secret_plane_unlocked:
		_show_locked_secret_plane()
		return

	_select_player(player_4_scene, PLANE_4_TEXTURE, PLANE_4_PREVIEW_SCALE, PLANE_4_PREVIEW_PROPELLERS, "NIGHT REAPER", plane_4_button)

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
	plane_preview.modulate = Color.WHITE
	plane_preview.scale = Vector2.ONE * preview_scale
	_refresh_preview_propellers(preview_propeller_positions)
	lock_status.visible = false
	stats.visible = true
	start_button.disabled = false

	var plane = player_scene.instantiate()
	var shots_per_second: float = 1.0 / plane.rate_of_fire
	if plane.default_twin_cannons:
		shots_per_second *= 2.0

	selected_plane_label.text = "%s  |  %d LIVES" % [plane_name, plane.max_lives]
	speed_bar.value = plane.speed
	speed_value.text = str(plane.speed)
	fire_rate_bar.value = shots_per_second
	fire_rate_value.text = "%.1f/s" % shots_per_second
	control_bar.value = plane.control_rating
	control_value.text = "%d/5" % plane.control_rating

	plane.free()

	for button in [plane_1_button, plane_2_button, plane_3_button, plane_4_button]:
		button.modulate = DEFAULT_BUTTON_COLOR

	selected_button.modulate = SELECTED_BUTTON_COLOR


func _show_locked_secret_plane() -> void:
	plane_preview.texture = PLANE_4_TEXTURE
	plane_preview.scale = Vector2.ONE * PLANE_4_PREVIEW_SCALE
	plane_preview.modulate = Color(0.08, 0.1, 0.14, 0.92)
	_refresh_preview_propellers([])
	selected_plane_label.text = "CLASSIFIED AIRCRAFT  |  LOCKED"
	lock_status.text = "REACH 100,000 IN ONE MISSION\nBEST: %s / 100,000" % GameData.format_number(GameData.get_high_score())
	lock_status.visible = true
	stats.visible = false
	start_button.disabled = true

	for button in [plane_1_button, plane_2_button, plane_3_button, plane_4_button]:
		button.modulate = DEFAULT_BUTTON_COLOR

	plane_4_button.modulate = SELECTED_BUTTON_COLOR


func _refresh_secret_plane_state() -> void:
	plane_4_button.text = "NIGHT REAPER" if GameData.secret_plane_unlocked else "CLASSIFIED"


func _restore_saved_plane() -> void:
	match GameData.selected_plane_name:
		"PLANE 2":
			_select_player(player_2_scene, PLANE_2_TEXTURE, PLANE_2_PREVIEW_SCALE, PLANE_2_PREVIEW_PROPELLERS, "PLANE 2", plane_2_button)
		"PLANE 3":
			_select_player(player_3_scene, PLANE_3_TEXTURE, PLANE_3_PREVIEW_SCALE, PLANE_3_PREVIEW_PROPELLERS, "PLANE 3", plane_3_button)
		"NIGHT REAPER":
			if GameData.secret_plane_unlocked:
				_select_player(player_4_scene, PLANE_4_TEXTURE, PLANE_4_PREVIEW_SCALE, PLANE_4_PREVIEW_PROPELLERS, "NIGHT REAPER", plane_4_button)
			else:
				_select_player(player_1_scene, PLANE_1_TEXTURE, PLANE_1_PREVIEW_SCALE, PLANE_1_PREVIEW_PROPELLERS, "PLANE 1", plane_1_button)
		_:
			_select_player(player_1_scene, PLANE_1_TEXTURE, PLANE_1_PREVIEW_SCALE, PLANE_1_PREVIEW_PROPELLERS, "PLANE 1", plane_1_button)


func _restore_saved_map() -> void:
	match GameData.selected_map_id:
		"grassland":
			_select_map("grassland", GameData.get_theater_name("grassland"), GRASSLAND_TEXTURE, grassland_button)
		"desert":
			_select_map("desert", GameData.get_theater_name("desert"), DESERT_TEXTURE, desert_button)
		_:
			_select_map("ocean", GameData.get_theater_name("ocean"), OCEAN_TEXTURE, ocean_button)


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
	map_selected.emit(map_id)

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


func _on_plane_4_pressed() -> void:
	_on_plane4_button_pressed()


func _on_ocean_pressed() -> void:
	_select_map("ocean", "ENGLISH CHANNEL", OCEAN_TEXTURE, ocean_button)


func _on_grassland_pressed() -> void:
	_select_map("grassland", "FRENCH COUNTRYSIDE", GRASSLAND_TEXTURE, grassland_button)


func _on_desert_pressed() -> void:
	_select_map("desert", "NORTH AFRICAN FRONT", DESERT_TEXTURE, desert_button)


func _on_leaderboard_pressed() -> void:
	for propeller in preview_propellers:
		propeller.visible = false
	leaderboard_modal_blocker.visible = true
	_populate_leaderboard()
	leaderboard_overlay.visible = true


func _on_close_leaderboard_pressed() -> void:
	leaderboard_overlay.visible = false
	leaderboard_modal_blocker.visible = false
	for propeller in preview_propellers:
		propeller.visible = true


func _populate_leaderboard() -> void:
	for child in leaderboard_entries.get_children():
		child.free()

	if GameData.leaderboard.is_empty():
		var empty_label := Label.new()
		empty_label.text = "NO MISSIONS RECORDED"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 14)
		leaderboard_entries.add_child(empty_label)
		return

	for index in mini(10, GameData.leaderboard.size()):
		var entry: Dictionary = GameData.leaderboard[index]
		leaderboard_entries.add_child(_create_menu_leaderboard_row(index + 1, entry))


func _create_menu_leaderboard_row(rank: int, entry: Dictionary) -> Panel:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0, 34)
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.04, 0.075, 0.09, 0.78) if rank % 2 == 1 else Color(0.025, 0.05, 0.065, 0.58)
	row_style.corner_radius_top_left = 3
	row_style.corner_radius_top_right = 3
	row_style.corner_radius_bottom_left = 3
	row_style.corner_radius_bottom_right = 3
	row.add_theme_stylebox_override("panel", row_style)

	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 3)
	row.add_child(columns)
	_add_menu_leaderboard_column(columns, "%02d" % rank, 28)
	_add_menu_leaderboard_column(columns, str(entry.get("pilot", "ROOKIE")), 88)
	_add_menu_leaderboard_column(columns, GameData.format_number(int(entry.get("score", 0))), 72)
	_add_menu_leaderboard_column(columns, str(entry.get("plane", "PLANE 1")), 86)
	_add_menu_leaderboard_column(columns, _get_menu_theater_short(str(entry.get("map", "ocean"))), 92)
	return row


func _add_menu_leaderboard_column(parent: HBoxContainer, value: String, width: float) -> void:
	var label := Label.new()
	label.custom_minimum_size.x = width
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	var font := get_theme_font("font")
	var font_size := 11
	while font_size > 8 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > width - 4.0:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)


func _get_menu_theater_short(map_id: String) -> String:
	return GameData.get_theater_short(map_id)


func _on_controls_pressed() -> void:
	for propeller in preview_propellers:
		propeller.visible = false
	controls_modal_blocker.visible = true
	controls_overlay.visible = true


func _on_close_controls_pressed() -> void:
	controls_overlay.visible = false
	controls_modal_blocker.visible = false
	for propeller in preview_propellers:
		propeller.visible = true


func _on_audio_pressed() -> void:
	for propeller in preview_propellers:
		propeller.visible = false
	music_slider.set_value_no_signal(GameData.music_volume * 100.0)
	sfx_slider.set_value_no_signal(GameData.sfx_volume * 100.0)
	_update_audio_labels()
	audio_modal_blocker.visible = true
	audio_overlay.visible = true


func _on_close_audio_pressed() -> void:
	GameData.save_settings()
	audio_overlay.visible = false
	audio_modal_blocker.visible = false
	for propeller in preview_propellers:
		propeller.visible = true


func _on_music_volume_changed(value: float) -> void:
	GameData.set_audio_levels(value / 100.0, GameData.sfx_volume)
	_update_audio_labels()


func _on_sfx_volume_changed(value: float) -> void:
	GameData.set_audio_levels(GameData.music_volume, value / 100.0)
	_update_audio_labels()


func _update_audio_labels() -> void:
	music_value.text = "%d%%" % roundi(music_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)
