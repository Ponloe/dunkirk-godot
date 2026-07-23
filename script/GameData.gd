extends Node

const LEADERBOARD_PATH := "user://leaderboard.json"
const DEFAULT_PILOT_NAME := "ROOKIE"
const MAX_PILOT_NAME_LENGTH := 12
const MAX_LEADERBOARD_ENTRIES := 10
const SECRET_PLANE_UNLOCK_SCORE := 100000
const MAP_NAMES := {
	"ocean": "ENGLISH CHANNEL",
	"grassland": "FRENCH COUNTRYSIDE",
	"desert": "NORTH AFRICAN FRONT"
}
const MAP_SHORT_NAMES := {
	"ocean": "CHANNEL",
	"grassland": "FRANCE",
	"desert": "N. AFRICA"
}

var pilot_name := DEFAULT_PILOT_NAME
var selected_player_scene: PackedScene = preload("res://player_plane/player.tscn")
var selected_plane_name := "PLANE 1"
var selected_map_id := "ocean"
var auto_start_on_reload := false
var leaderboard: Array[Dictionary] = []
var secret_plane_unlocked := false
var music_volume := 0.75
var sfx_volume := 0.85
var guidance_seen: Dictionary = {}
var achievements: Dictionary = {}


func _ready() -> void:
	_load_leaderboard()
	apply_audio_settings()


func set_pilot_name(value: String) -> String:
	pilot_name = _sanitize_pilot_name(value)
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
	_save_leaderboard()


func reset_loadout_selection() -> void:
	selected_player_scene = preload("res://player_plane/player.tscn")
	selected_plane_name = "PLANE 1"
	selected_map_id = "ocean"
	_save_leaderboard()


func unlock_achievement(achievement_id: String) -> bool:
	if bool(achievements.get(achievement_id, false)):
		return false
	achievements[achievement_id] = true
	_save_leaderboard()
	return true


func submit_score(score: int) -> int:
	var entry := {
		"submission_id": "%s-%s" % [Time.get_unix_time_from_system(), randi()],
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

	var rank := -1
	for index in leaderboard.size():
		if str(leaderboard[index].get("submission_id", "")) == str(entry.submission_id):
			rank = index + 1
			break

	if leaderboard.size() > MAX_LEADERBOARD_ENTRIES:
		leaderboard.resize(MAX_LEADERBOARD_ENTRIES)

	_save_leaderboard()
	return rank if rank <= MAX_LEADERBOARD_ENTRIES else -1


func get_high_score() -> int:
	if leaderboard.is_empty():
		return 0

	return int(leaderboard[0].get("score", 0))


func unlock_secret_plane() -> bool:
	if secret_plane_unlocked:
		return false

	secret_plane_unlocked = true
	_save_leaderboard()
	return true


func set_audio_levels(music: float, effects: float) -> void:
	music_volume = clampf(music, 0.0, 1.0)
	sfx_volume = clampf(effects, 0.0, 1.0)
	apply_audio_settings()


func save_settings() -> void:
	_save_leaderboard()


func apply_audio_settings() -> void:
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)


func mark_guidance_seen(guidance_id: String) -> bool:
	if bool(guidance_seen.get(guidance_id, false)):
		return false

	guidance_seen[guidance_id] = true
	_save_leaderboard()
	return true


func _set_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return

	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(maxf(linear_volume, 0.0001))
	)
	AudioServer.set_bus_mute(bus_index, linear_volume <= 0.001)


func get_theater_name(map_id: String) -> String:
	return str(MAP_NAMES.get(map_id, MAP_NAMES.ocean))


func get_theater_short(map_id: String) -> String:
	return str(MAP_SHORT_NAMES.get(map_id, MAP_SHORT_NAMES.ocean))


func format_number(value: int) -> String:
	var raw := str(maxi(0, value))
	var result := ""
	while raw.length() > 3:
		result = "," + raw.right(3) + result
		raw = raw.left(raw.length() - 3)
	return raw + result


func _load_leaderboard() -> void:
	if not FileAccess.file_exists(LEADERBOARD_PATH):
		return

	var save_file := FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)

	if save_file == null:
		return

	var parsed = JSON.parse_string(save_file.get_as_text())

	if not parsed is Dictionary:
		return

	pilot_name = _sanitize_pilot_name(str(parsed.get("last_pilot", DEFAULT_PILOT_NAME)))
	secret_plane_unlocked = bool(parsed.get("secret_plane_unlocked", false))
	music_volume = clampf(float(parsed.get("music_volume", 0.75)), 0.0, 1.0)
	sfx_volume = clampf(float(parsed.get("sfx_volume", 0.85)), 0.0, 1.0)
	selected_plane_name = str(parsed.get("selected_plane", "PLANE 1"))
	selected_map_id = str(parsed.get("selected_map", "ocean"))
	if not MAP_NAMES.has(selected_map_id):
		selected_map_id = "ocean"
	var saved_achievements = parsed.get("achievements", {})
	if saved_achievements is Dictionary:
		achievements = saved_achievements
	var saved_guidance = parsed.get("guidance_seen", {})
	if saved_guidance is Dictionary:
		guidance_seen = saved_guidance
	var saved_scores = parsed.get("scores", [])

	leaderboard.clear()
	if saved_scores is Array:
		for saved_entry in saved_scores:
			if not saved_entry is Dictionary:
				continue
			leaderboard.append({
				"submission_id": str(saved_entry.get("submission_id", "")),
				"pilot": _sanitize_pilot_name(str(saved_entry.get("pilot", DEFAULT_PILOT_NAME))),
				"score": maxi(0, int(saved_entry.get("score", 0))),
				"plane": str(saved_entry.get("plane", "PLANE 1")),
				"map": str(saved_entry.get("map", "ocean")) if MAP_NAMES.has(str(saved_entry.get("map", "ocean"))) else "ocean",
				"created_at": float(saved_entry.get("created_at", 0.0))
			})
	leaderboard.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return int(first.get("score", 0)) > int(second.get("score", 0))
	)
	if leaderboard.size() > MAX_LEADERBOARD_ENTRIES:
		leaderboard.resize(MAX_LEADERBOARD_ENTRIES)

	if get_high_score() >= SECRET_PLANE_UNLOCK_SCORE:
		secret_plane_unlocked = true
	_restore_selected_player_scene()


func _save_leaderboard() -> void:
	var save_file := FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)

	if save_file == null:
		return

	save_file.store_string(JSON.stringify({
		"last_pilot": pilot_name,
		"selected_plane": selected_plane_name,
		"selected_map": selected_map_id,
		"secret_plane_unlocked": secret_plane_unlocked,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"achievements": achievements,
		"guidance_seen": guidance_seen,
		"scores": leaderboard
	}))


func _sanitize_pilot_name(value: String) -> String:
	var cleaned := value.strip_edges().to_upper().substr(0, MAX_PILOT_NAME_LENGTH)
	return DEFAULT_PILOT_NAME if cleaned.is_empty() else cleaned


func _restore_selected_player_scene() -> void:
	match selected_plane_name:
		"PLANE 2":
			selected_player_scene = preload("res://player_plane/player_2.tscn")
		"PLANE 3":
			selected_player_scene = preload("res://player_plane/player_3.tscn")
		"NIGHT REAPER":
			if secret_plane_unlocked:
				selected_player_scene = preload("res://player_plane/player_4.tscn")
			else:
				selected_player_scene = preload("res://player_plane/player.tscn")
				selected_plane_name = "PLANE 1"
				selected_map_id = "ocean"
		_:
			selected_player_scene = preload("res://player_plane/player.tscn")
			selected_plane_name = "PLANE 1"
