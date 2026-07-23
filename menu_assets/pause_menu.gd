extends Control

signal resume_requested
signal restart_requested
signal main_menu_requested

@onready var menu_panel: Panel = $MenuPanel
@onready var controls_overlay: Panel = $ControlsOverlay
@onready var music_slider: HSlider = $MenuPanel/MusicSlider
@onready var sfx_slider: HSlider = $MenuPanel/SFXSlider
@onready var music_value: Label = $MenuPanel/MusicValue
@onready var sfx_value: Label = $MenuPanel/SFXValue
var audio_dirty := false


func _ready() -> void:
	visible = false
	controls_overlay.visible = false
	call_deferred("_fit_menu_text")


func open() -> void:
	music_slider.set_value_no_signal(GameData.music_volume * 100.0)
	sfx_slider.set_value_no_signal(GameData.sfx_volume * 100.0)
	_update_volume_labels()
	menu_panel.visible = true
	controls_overlay.visible = false
	visible = true
	call_deferred("_fit_menu_text")


func close() -> void:
	_commit_audio_settings()
	visible = false
	controls_overlay.visible = false


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_controls_pressed() -> void:
	menu_panel.visible = false
	controls_overlay.visible = true


func _on_close_controls_pressed() -> void:
	controls_overlay.visible = false
	menu_panel.visible = true


func _on_restart_pressed() -> void:
	_commit_audio_settings()
	restart_requested.emit()


func _on_main_menu_pressed() -> void:
	_commit_audio_settings()
	main_menu_requested.emit()


func _on_music_volume_changed(value: float) -> void:
	GameData.set_audio_levels(value / 100.0, GameData.sfx_volume)
	audio_dirty = true
	_update_volume_labels()


func _on_sfx_volume_changed(value: float) -> void:
	GameData.set_audio_levels(GameData.music_volume, value / 100.0)
	audio_dirty = true
	_update_volume_labels()


func _update_volume_labels() -> void:
	music_value.text = "%d%%" % roundi(music_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)


func _commit_audio_settings() -> void:
	if not audio_dirty:
		return
	GameData.save_settings()
	audio_dirty = false


func _fit_menu_text() -> void:
	_fit_control_text($MenuPanel/Title, $MenuPanel/Title.text, 29, 20, 12.0)
	_fit_control_text($MenuPanel/Subtitle, $MenuPanel/Subtitle.text, 11, 8, 10.0)
	_fit_control_text($MenuPanel/Resume, $MenuPanel/Resume.text, 22, 15, 20.0)
	_fit_control_text($MenuPanel/Controls, $MenuPanel/Controls.text, 18, 13, 20.0)
	_fit_control_text($MenuPanel/MusicLabel, $MenuPanel/MusicLabel.text, 14, 10, 4.0)
	_fit_control_text($MenuPanel/SFXLabel, $MenuPanel/SFXLabel.text, 14, 10, 4.0)
	_fit_control_text($MenuPanel/Restart, $MenuPanel/Restart.text, 18, 12, 20.0)
	_fit_control_text($MenuPanel/MainMenu, $MenuPanel/MainMenu.text, 18, 12, 20.0)
	_fit_control_text($MenuPanel/Hint, $MenuPanel/Hint.text, 10, 7, 10.0)


func _fit_control_text(control: Control, value: String, maximum_size: int, minimum_size: int, horizontal_padding: float) -> void:
	var font := control.get_theme_font("font")
	var available_width := maxf(1.0, control.size.x - horizontal_padding)
	var fitted_size := maximum_size
	while fitted_size > minimum_size and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size).x > available_width:
		fitted_size -= 1
	control.add_theme_font_size_override("font_size", fitted_size)
