extends Control

signal continue_requested
signal finish_requested


func _ready() -> void:
	call_deferred("_fit_screen_text")


func set_mission_target(target: int) -> void:
	var count_text := _number_word(target)
	$Panel/Objective.text = "%s ENEMY %s DEFEATED" % [
		count_text,
		"ACE" if target == 1 else "ACES"
	]
	call_deferred("_fit_screen_text")


func _fit_screen_text() -> void:
	_fit_control_text($Panel/Title, $Panel/Title.text, 30, 20, 16.0)
	_fit_control_text($Panel/Objective, $Panel/Objective.text, 18, 12, 16.0)
	_fit_control_text($Panel/Message, $Panel/Message.text, 16, 11, 16.0)
	_fit_control_text($Panel/ChoicePrompt, $Panel/ChoicePrompt.text, 17, 11, 16.0)
	_fit_control_text($Panel/Continue, $Panel/Continue.text, 21, 14, 24.0)
	_fit_control_text($Panel/Finish, $Panel/Finish.text, 20, 14, 24.0)


func _fit_control_text(control: Control, value: String, maximum_size: int, minimum_size: int, horizontal_padding: float) -> void:
	var font := control.get_theme_font("font")
	var available_width := maxf(1.0, control.size.x - horizontal_padding)
	var fitted_size := maximum_size
	while fitted_size > minimum_size:
		var widest_line := 0.0
		for line in value.split("\n"):
			widest_line = maxf(widest_line, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size).x)
		if widest_line <= available_width:
			break
		fitted_size -= 1
	control.add_theme_font_size_override("font_size", fitted_size)


func _number_word(value: int) -> String:
	match value:
		1: return "ONE"
		2: return "TWO"
		3: return "THREE"
		4: return "FOUR"
		5: return "FIVE"
		_: return str(value)


func _on_continue_pressed() -> void:
	continue_requested.emit()


func _on_finish_pressed() -> void:
	finish_requested.emit()
