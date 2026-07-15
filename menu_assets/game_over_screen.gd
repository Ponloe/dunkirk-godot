extends Control


func show_results(score: int, rank: int) -> void:
	$Panel/Pilot.text = "PILOT: " + GameData.pilot_name
	$Panel/Score.text = "MISSION SCORE: " + str(score)
	$Panel/HighScore.text = "PERSONAL BEST: " + str(GameData.get_high_score())
	$Panel/Rank.text = "TOP 10 RANK: #%d" % rank if rank > 0 else "TOP 10 RANK: --"
	$Panel/Loadout.text = "%s  |  %s" % [
		GameData.selected_plane_name,
		GameData.selected_map_id.to_upper()
	]
	$Panel/Leaderboard.text = GameData.format_leaderboard(5)


func _on_retry_button_pressed() -> void:
	GameData.auto_start_on_reload = true
	get_tree().reload_current_scene()


func _on_loadout_button_pressed() -> void:
	GameData.auto_start_on_reload = false
	get_tree().reload_current_scene()


func _on_main_menu_button_pressed() -> void:
	GameData.auto_start_on_reload = false
	get_tree().reload_current_scene()
