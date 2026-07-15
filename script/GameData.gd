extends Node

const LEADERBOARD_PATH := "user://leaderboard.json"
const DEFAULT_PILOT_NAME := "ROOKIE"
const MAX_PILOT_NAME_LENGTH := 12
const MAX_LEADERBOARD_ENTRIES := 10

var pilot_name := DEFAULT_PILOT_NAME
var selected_player_scene: PackedScene = preload("res://player_plane/player.tscn")
var selected_plane_name := "PLANE 1"
var selected_map_id := "ocean"
var auto_start_on_reload := false
var leaderboard: Array[Dictionary] = []


func _ready() -> void:
	_load_leaderboard()


func set_pilot_name(value: String) -> String:
	var cleaned := value.strip_edges().to_upper()
	cleaned = cleaned.substr(0, MAX_PILOT_NAME_LENGTH)

	if cleaned.is_empty():
		cleaned = DEFAULT_PILOT_NAME

	pilot_name = cleaned
	_save_leaderboard()
	return pilot_name


func set_loadout(
	player_scene: PackedScene,
	plane_name: String,
	map_id: String
) -> void:
	selected_player_scene = player_scene
	selected_plane_name = plane_name
	selected_map_id = map_id


func submit_score(score: int) -> int:
	var entry := {
		"pilot": pilot_name,
		"score": score,
		"plane": selected_plane_name,
		"map": selected_map_id,
		"created_at": Time.get_unix_time_from_system()
	}

	leaderboard.append(entry)
	leaderboard.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return int(first.get("score", 0)) > int(second.get("score", 0))
	)

	var rank := leaderboard.find(entry) + 1

	if leaderboard.size() > MAX_LEADERBOARD_ENTRIES:
		leaderboard.resize(MAX_LEADERBOARD_ENTRIES)

	_save_leaderboard()
	return rank if rank <= MAX_LEADERBOARD_ENTRIES else -1


func get_high_score() -> int:
	if leaderboard.is_empty():
		return 0

	return int(leaderboard[0].get("score", 0))


func format_leaderboard(limit := MAX_LEADERBOARD_ENTRIES) -> String:
	if leaderboard.is_empty():
		return "NO MISSIONS RECORDED"

	var lines: Array[String] = []
	var entry_count := mini(limit, leaderboard.size())

	for index in entry_count:
		var entry := leaderboard[index]
		lines.append(
			"%02d. %-12s  %06d" % [
				index + 1,
				str(entry.get("pilot", DEFAULT_PILOT_NAME)),
				int(entry.get("score", 0))
			]
		)

	return "\n".join(lines)


func _load_leaderboard() -> void:
	if not FileAccess.file_exists(LEADERBOARD_PATH):
		return

	var save_file := FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)

	if save_file == null:
		return

	var parsed = JSON.parse_string(save_file.get_as_text())

	if not parsed is Dictionary:
		return

	pilot_name = str(parsed.get("last_pilot", DEFAULT_PILOT_NAME))
	var saved_scores = parsed.get("scores", [])

	if saved_scores is Array:
		leaderboard.assign(saved_scores)


func _save_leaderboard() -> void:
	var save_file := FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)

	if save_file == null:
		return

	save_file.store_string(JSON.stringify({
		"last_pilot": pilot_name,
		"scores": leaderboard
	}))
