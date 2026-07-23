extends Control

const ACCENTS := {
	"ocean": Color("43b8d8"),
	"grassland": Color("9ebd52"),
	"desert": Color("ff7a18")
}


func show_results(score: int, rank: int, mission_success := false, stats := {}) -> void:
	var accent: Color = ACCENTS.get(GameData.selected_map_id, ACCENTS.ocean)
	_apply_map_accent(accent)
	$Panel/Title.text = "MISSION COMPLETE" if mission_success else "MISSION FAILED"
	$Panel/Subtitle.text = "OBJECTIVES COMPLETE" if mission_success else "AIRCRAFT DESTROYED IN COMBAT"
	$Panel/Pilot.text = "PILOT: " + GameData.pilot_name
	$Panel/Rank.text = "RANK #%d" % rank if rank > 0 else "UNRANKED"
	$Panel/Loadout.text = "%s  •  %s" % [
		GameData.selected_plane_name,
		_get_theater_name(GameData.selected_map_id)
	]
	$Panel/Score.text = _format_number(score)
	$Panel/HighScore.text = "PERSONAL BEST: " + _format_number(GameData.get_high_score())
	_set_best_comparison(score, rank)
	$Panel/StatsRow/Enemies/Value.text = str(int(stats.get("enemies", 0)))
	$Panel/StatsRow/Bosses/Value.text = str(int(stats.get("bosses", 0)))
	$Panel/StatsRow/Combo/Value.text = str(int(stats.get("combo", 0)))
	var elapsed := int(float(stats.get("time", 0.0)))
	$Panel/StatsRow/Time/Value.text = "%02d:%02d" % [elapsed / 60, elapsed % 60]
	_build_leaderboard(rank)
	_fit_result_text()
	call_deferred("_fit_result_text")


func _set_best_comparison(score: int, rank: int) -> void:
	var previous_best := 0
	for index in GameData.leaderboard.size():
		if index == rank - 1:
			continue
		previous_best = maxi(previous_best, int(GameData.leaderboard[index].get("score", 0)))
	if score > previous_best:
		$Panel/BestComparison.text = "NEW PERSONAL BEST!"
		$Panel/BestComparison.modulate = Color("ff7a18")
	elif score == previous_best:
		$Panel/BestComparison.text = "PERSONAL BEST TIED!"
		$Panel/BestComparison.modulate = Color("ffe49a")
	else:
		$Panel/BestComparison.text = "%s POINTS BELOW RECORD" % _format_number(previous_best - score)
		$Panel/BestComparison.modulate = Color("9daab2")


func _build_leaderboard(current_rank: int) -> void:
	var rows: VBoxContainer = $Panel/LeaderboardCard/Rows
	for child in rows.get_children():
		child.free()
	for index in mini(5, GameData.leaderboard.size()):
		var entry: Dictionary = GameData.leaderboard[index]
		rows.add_child(_create_leaderboard_row(index + 1, entry, index + 1 == current_rank))


func _create_leaderboard_row(rank: int, entry: Dictionary, highlighted: bool) -> Panel:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.72, 0.25, 0.03, 0.72) if highlighted else Color(0.02, 0.05, 0.07, 0.35)
	style.border_width_left = 2 if highlighted else 0
	style.border_color = Color("ff9a2e")
	row.add_theme_stylebox_override("panel", style)
	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 3)
	row.add_child(columns)
	_add_column(columns, ("▶" if highlighted else "") + str(rank), 22, highlighted)
	_add_column(columns, str(entry.get("pilot", "ROOKIE")), 88, highlighted)
	_add_column(columns, GameData.format_number(int(entry.get("score", 0))), 72, highlighted)
	_add_column(columns, str(entry.get("plane", "PLANE 1")), 82, highlighted)
	_add_column(columns, _get_theater_short(str(entry.get("map", "ocean"))), 92, highlighted)
	return row


func _add_column(parent: HBoxContainer, value: String, width: float, highlighted: bool) -> void:
	var label := Label.new()
	label.custom_minimum_size.x = width
	label.text = value
	label.add_theme_font_size_override("font_size", _get_fitting_font_size(value, width - 4.0, 11, 8))
	label.add_theme_color_override("font_color", Color("ffe49a") if highlighted else Color("d8dee2"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	parent.add_child(label)


func _fit_result_text() -> void:
	_fit_label($Panel/Title, 32, 22)
	_fit_label($Panel/Subtitle, 10, 8)
	_fit_label($Panel/Pilot, 14, 8)
	_fit_label($Panel/Rank, 14, 8)
	_fit_label($Panel/Loadout, 10, 7)
	_fit_label($Panel/Score, 44, 24)
	_fit_label($Panel/ScoreCaption, 16, 11)
	_fit_label($Panel/HighScore, 12, 8)
	_fit_label($Panel/BestComparison, 10, 7)

	for stat_panel in $Panel/StatsRow.get_children():
		_fit_label(stat_panel.get_node("Value"), 16, 9)
		_fit_label(stat_panel.get_node("Name"), 10, 7)


func _fit_label(label: Label, maximum_size: int, minimum_size: int) -> void:
	var available_width := maxf(1.0, label.size.x - 8.0)
	var settings := label.label_settings
	var font: Font = settings.font if settings != null and settings.font != null else label.get_theme_font("font")
	var fitted_size := _measure_fitting_font_size(font, label.text, available_width, maximum_size, minimum_size)

	if settings != null:
		var fitted_settings: LabelSettings = settings.duplicate()
		fitted_settings.font_size = fitted_size
		label.label_settings = fitted_settings
	else:
		label.add_theme_font_size_override("font_size", fitted_size)

	label.clip_text = true


func _get_fitting_font_size(value: String, available_width: float, maximum_size: int, minimum_size: int) -> int:
	return _measure_fitting_font_size(get_theme_font("font"), value, available_width, maximum_size, minimum_size)


func _measure_fitting_font_size(font: Font, value: String, available_width: float, maximum_size: int, minimum_size: int) -> int:
	if font == null:
		return minimum_size

	var fitted_size := maximum_size
	while fitted_size > minimum_size:
		var text_width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size).x
		if text_width <= available_width:
			break
		fitted_size -= 1

	return fitted_size


func _apply_map_accent(accent: Color) -> void:
	var frame: StyleBoxFlat = $Panel.get_theme_stylebox("panel").duplicate()
	frame.border_color = accent
	$Panel.add_theme_stylebox_override("panel", frame)
	$Panel/HeaderBand.color = Color(accent, 0.18)


func _get_theater_name(map_id: String) -> String:
	return GameData.get_theater_name(map_id)


func _get_theater_short(map_id: String) -> String:
	return GameData.get_theater_short(map_id)


func _format_number(value: int) -> String:
	return GameData.format_number(value)


func _on_retry_button_pressed() -> void:
	GameData.auto_start_on_reload = true
	get_tree().reload_current_scene()


func _on_loadout_button_pressed() -> void:
	GameData.auto_start_on_reload = false
	get_tree().reload_current_scene()


func _on_main_menu_button_pressed() -> void:
	GameData.reset_loadout_selection()
	GameData.auto_start_on_reload = false
	get_tree().reload_current_scene()
