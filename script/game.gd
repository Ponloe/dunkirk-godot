extends Node2D

@export_category("Enemy Spawning")
@export var enemy_scenes: Array[PackedScene] = []
@export var spawn_x_min := 50.0
@export var spawn_x_max := 500.0
@export var spawn_y := -50.0
@export var minimum_spawn_wait_time := 2.2
@export var spawn_wait_acceleration := 0.03
@export var wave_interval := 4.0

@export_category("Formation")
@export var formation_score_interval := 1000

@export_category("Power-Up Drops")
@export var power_up_scene: PackedScene = preload("res://power_up.tscn")
@export_range(0.0, 1.0) var basic_drop_chance := 0.06
@export_range(0.0, 1.0) var formation_drop_chance := 0.18
@export var guaranteed_drop_kills := 15

@export_category("Boss Encounter")
@export var boss_scene: PackedScene
@export var first_boss_score := 6000
@export var boss_score_interval := 8000
@export var boss_spawn_y := -150.0
@export var boss_warning_duration := 3.0
@export var difficulty_increase_per_boss := 0.25

@export_category("Other Settings")
@export var parallax_scroll_speed := 100.0
@export var easter_egg_score_bonus := 5000
@export var combo_window := 3.0
@export var mission_boss_target := 3


@onready var player_spawn_pos = $PlayerSpawnPos
@onready var bullet_container = $BulletContainer
@onready var timer = $EnemySpawnTimer
@onready var enemy_container = $EnemyContainer
@onready var power_up_container = $PowerUpContainer

@onready var main_menu = $UILayer/MainMenu
@onready var hud = $UILayer/HUD
@onready var gos = $UILayer/GameOverScreen
@onready var pause_menu = $UILayer/PauseMenu
@onready var mission_complete = $UILayer/MissionComplete
@onready var pb = $ParallaxBackground
@onready var background_layer: ParallaxLayer = $ParallaxBackground/ParallaxLayer
@onready var background_sprite: Sprite2D = $ParallaxBackground/ParallaxLayer/cloud
@onready var map_effects: Node2D = $MapEffects
@onready var game_camera: Camera2D = $Camera2D

@onready var gun_sound = $SFX/GunSound
@onready var engine_sound = $SFX/EngineSound
@onready var hit_sound = $SFX/HitSound
@onready var explode_sound = $SFX/ExplodeSound
@onready var bg_sound = $SFX/BgSound
@onready var easter_sound = $SFX/Easter


const V_FORMATION_OFFSETS = [
	Vector2(0, 0),
	Vector2(-70, -60),
	Vector2(70, -60),
	Vector2(-140, -120),
	Vector2(140, -120)
]

const HORIZONTAL_LINE_OFFSETS = [
	Vector2(-180, 0),
	Vector2(-60, 0),
	Vector2(60, 0),
	Vector2(180, 0)
]

const COLUMN_OFFSETS = [
	Vector2(-130, 0),
	Vector2(-130, -90),
	Vector2(0, -45),
	Vector2(130, 0),
	Vector2(130, -90)
]

const DIAGONAL_OFFSETS = [
	Vector2(-180, 0),
	Vector2(-90, -55),
	Vector2(0, -110),
	Vector2(90, -165),
	Vector2(180, -220)
]

const EASTER_SEQUENCE = [
	"ui_up", "ui_up", "ui_down", "ui_down",
	"ui_left", "ui_right", "ui_left", "ui_right"
]

const OCEAN_TEXTURE: Texture2D = preload("res://assets/ocean.png")
const GRASSLAND_TEXTURE: Texture2D = preload("res://assets/greenland_seamless.png")
const DESERT_TEXTURE: Texture2D = preload("res://assets/desertland_seamless.png")


var easter_buffer: Array[String] = []
var actions_to_check = [
	"ui_up",
	"ui_down",
	"ui_left",
	"ui_right"
]

var is_easter_playing := false

var next_formation_milestone := 1000
var next_boss_milestone := 6000

var boss_active := false
var current_boss = null

var difficulty_multiplier := 1.0
var player = null
var high_score := 0
var enemies_defeated := 0
var last_power_up_type := ""
var current_map_id := "ocean"
var wave_index := 0
var bosses_defeated := 0
var combo_count := 0
var combo_time_remaining := 0.0
var last_player_lives := 0
var mission_milestone_shown := false
var highest_combo := 0
var run_time := 0.0
var bombs_used := 0
var player_hit_during_boss := false
var shake_time_remaining := 0.0
var shake_strength := 0.0
var game_over_pending := false
var bomb_clear_active := false


var score := 0:
	set(value):
		score = value
		hud.score = score

		if score > high_score:
			high_score = score

		if score >= GameData.SECRET_PLANE_UNLOCK_SCORE:
			if GameData.unlock_secret_plane():
				hud.show_secret_plane_unlocked()
		_check_score_medals()

		# Boss is checked first so a formation does not spawn
		# at the same milestone as a boss.
		_check_boss_milestone()
		_check_formation_milestone()


func _ready() -> void:
	next_formation_milestone = formation_score_interval
	next_boss_milestone = first_boss_score

	main_menu.start_game.connect(_on_main_menu_start_game)
	main_menu.map_selected.connect(_on_main_menu_map_selected)
	pause_menu.resume_requested.connect(_on_pause_resume_requested)
	pause_menu.restart_requested.connect(_on_pause_restart_requested)
	pause_menu.main_menu_requested.connect(_on_pause_main_menu_requested)
	mission_complete.continue_requested.connect(_on_continue_endless_requested)
	mission_complete.finish_requested.connect(_on_finish_mission_requested)

	bg_sound.play()

	process_mode = Node.PROCESS_MODE_ALWAYS
	bg_sound.process_mode = Node.PROCESS_MODE_ALWAYS

	engine_sound.stop()
	timer.stop()

	high_score = GameData.get_high_score()

	score = 0
	hud.set_kill_progress(0, guaranteed_drop_kills)

	main_menu.visible = true
	hud.visible = false
	gos.visible = false
	pause_menu.visible = false
	mission_complete.visible = false
	get_tree().paused = true

	if GameData.auto_start_on_reload:
		GameData.auto_start_on_reload = false
		main_menu.visible = false
		call_deferred(
			"_on_main_menu_start_game",
			GameData.selected_player_scene,
			GameData.selected_map_id,
			GameData.pilot_name
		)


func _on_main_menu_start_game(
	selected_player_scene: PackedScene,
	selected_map_id: String,
	pilot_name: String
) -> void:
	if selected_player_scene == null:
		push_error(
			"No player scene selected. Check MainMenu exported player scenes."
		)
		return

	get_tree().paused = false
	GameData.set_pilot_name(pilot_name)

	score = 0
	enemies_defeated = 0
	wave_index = 0
	bosses_defeated = 0
	combo_count = 0
	combo_time_remaining = 0.0
	mission_milestone_shown = false
	highest_combo = 0
	run_time = 0.0
	bombs_used = 0
	player_hit_during_boss = false
	game_over_pending = false
	current_map_id = selected_map_id
	difficulty_multiplier = 1.0
	hud.set_kill_progress(0, guaranteed_drop_kills)
	hud.clear_power_ups()
	hud.visible = true
	_apply_selected_map(selected_map_id)
	hud.show_level_intro(_get_level_title(selected_map_id))

	boss_active = false
	current_boss = null

	next_formation_milestone = formation_score_interval
	next_boss_milestone = first_boss_score

	if player != null:
		player.queue_free()

	player = selected_player_scene.instantiate()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.global_position = player_spawn_pos.global_position

	player.bullet_shot.connect(_on_player_bullet_shot)
	player.killed.connect(_on_player_killed)
	player.lives_changed.connect(_on_player_lives_changed)
	player.power_up_started.connect(hud.show_power_up)
	player.power_up_ended.connect(hud.hide_power_up)
	player.bomb_requested.connect(_on_player_bomb_requested)
	player.hit_received.connect(_on_player_hit_received)

	add_child(player)
	last_player_lives = player.current_lives
	hud.set_lives(player.current_lives, player.max_lives)
	hud.set_combo(0, 1.0)

	engine_sound.play()
	timer.wait_time = wave_interval
	timer.start()
	_show_start_guidance()


func _on_main_menu_map_selected(map_id: String) -> void:
	if not main_menu.visible:
		return

	current_map_id = map_id
	_apply_selected_map(map_id)


func _process(delta: float) -> void:
	var focused_control := get_viewport().gui_get_focus_owner()
	var is_entering_text := (
		focused_control is LineEdit
		or focused_control is TextEdit
	)

	if not is_entering_text:
		if Input.is_action_just_pressed("pause"):
			_toggle_pause_menu()

		for action in actions_to_check:
			if Input.is_action_just_pressed(action):
				_update_easter_buffer(action)

	if not get_tree().paused:
		run_time += delta
		if combo_time_remaining > 0.0:
			combo_time_remaining = maxf(0.0, combo_time_remaining - delta)
			if combo_time_remaining <= 0.0:
				_reset_combo()

		if not boss_active:
			if timer.wait_time > minimum_spawn_wait_time:
				timer.wait_time = max(
					minimum_spawn_wait_time,
					timer.wait_time -
					delta *
					spawn_wait_acceleration *
					difficulty_multiplier
				)


	if not pause_menu.visible and not game_over_pending:
		_scroll_background(delta)
	if not get_tree().paused:
		if shake_time_remaining > 0.0:
			shake_time_remaining -= delta
			game_camera.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		else:
			shake_strength = 0.0
			game_camera.offset = game_camera.offset.lerp(Vector2.ZERO, minf(1.0, delta * 18.0))


func _toggle_pause_menu() -> void:
	if main_menu.visible or gos.visible or mission_complete.visible or game_over_pending:
		return

	if pause_menu.visible:
		_on_pause_resume_requested()
	else:
		get_tree().paused = true
		pause_menu.open()


func _on_pause_resume_requested() -> void:
	pause_menu.close()
	get_tree().paused = false


func _on_pause_restart_requested() -> void:
	GameData.auto_start_on_reload = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_pause_main_menu_requested() -> void:
	GameData.auto_start_on_reload = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _show_start_guidance() -> void:
	await get_tree().create_timer(3.1, false).timeout
	if player == null or not is_instance_valid(player):
		return

	if GameData.mark_guidance_seen("basic_controls"):
		hud.show_tip("WASD TO MOVE\nSPACE TO FIRE", 3.5)


func _on_player_bullet_shot(
	bullet_scene: PackedScene,
	location: Vector2,
	direction: Vector2
) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = location
	bullet.setup(direction)
	bullet_container.add_child(bullet)

	gun_sound.play()


# ---------------------------------------------------------
# NORMAL ENEMY SPAWNING
# ---------------------------------------------------------

func _on_enemy_spawn_timer_timeout() -> void:
	if boss_active:
		return

	if enemy_scenes.is_empty():
		push_warning("No enemy scenes assigned to enemy_scenes.")
		return

	_spawn_structured_wave()
	wave_index += 1


func _spawn_structured_wave() -> void:
	var pattern_names: Array[String]

	match current_map_id:
		"grassland":
			pattern_names = ["columns", "support", "v", "armored"]
		"desert":
			pattern_names = ["diagonal", "kamikaze", "line", "gunship"]
		_:
			pattern_names = ["v", "line", "patrol", "gunship", "kamikaze"]

	var pattern := pattern_names[wave_index % pattern_names.size()]
	var offsets := _get_wave_offsets(pattern)
	var enemy_scene := _get_wave_enemy_scene(pattern)
	var spawn_center_x := get_viewport_rect().size.x / 2.0

	for offset in offsets:
		_spawn_wave_enemy(
			enemy_scene,
			Vector2(spawn_center_x, spawn_y - 35.0) + offset
		)


func _get_wave_offsets(pattern: String) -> Array:
	match pattern:
		"armored", "gunship", "support":
			return [Vector2(-105, 0), Vector2(105, 0)]
		"kamikaze":
			return [Vector2(-145, 0), Vector2(0, -55), Vector2(145, 0)]
		"line":
			return HORIZONTAL_LINE_OFFSETS
		"columns", "staggered":
			return COLUMN_OFFSETS
		"diagonal", "zigzag":
			return DIAGONAL_OFFSETS
		_:
			return V_FORMATION_OFFSETS


func _get_wave_enemy_scene(pattern: String) -> PackedScene:
	var keyword := ""
	if pattern in ["v", "diagonal"]:
		keyword = "diver"
	elif pattern in ["armored", "kamikaze", "gunship", "support"]:
		keyword = pattern
	elif pattern == "patrol":
		keyword = "intercepter"
	elif pattern in ["zigzag", "staggered"]:
		keyword = "zig"

	for enemy_scene in enemy_scenes:
		if keyword in enemy_scene.resource_path.to_lower():
			return enemy_scene

	return enemy_scenes[wave_index % enemy_scenes.size()]


func _spawn_wave_enemy(enemy_scene: PackedScene, spawn_position: Vector2) -> void:
	var enemy = enemy_scene.instantiate()
	_apply_enemy_difficulty(enemy)
	enemy.global_position = spawn_position
	enemy.modulate = _get_level_enemy_tint()
	enemy.killed.connect(_on_enemy_killed.bind(basic_drop_chance))
	enemy.hit.connect(_on_enemy_hit)
	if enemy.has_signal("bullet_fired"):
		enemy.bullet_fired.connect(_on_boss_bullet_fired)
	enemy_container.add_child(enemy)


func _get_level_enemy_tint() -> Color:
	match current_map_id:
		"grassland":
			return Color(0.72, 1.0, 0.68)
		"desert":
			return Color(1.0, 0.72, 0.48)
		_:
			return Color(0.66, 0.86, 1.0)


func _apply_enemy_difficulty(enemy) -> void:
	# Each enemy is a new instance, so these changes do not
	# permanently modify the original enemy scene.
	enemy.speed *= difficulty_multiplier

	# HP increases more slowly than enemy speed.
	var hp_multiplier := (
		1.0 +
		((difficulty_multiplier - 1.0) * 0.5)
	)

	enemy.hp = max(
		1,
		roundi(enemy.hp * hp_multiplier)
	)

func _on_enemy_killed(
	points: int,
	drop_position: Vector2,
	drop_chance: float
) -> void:
	explode_sound.play()
	if bomb_clear_active:
		score += maxi(1, roundi(float(points) * 0.5))
	else:
		_award_combo_score(points)
	enemies_defeated += 1
	hud.set_kill_progress(enemies_defeated, guaranteed_drop_kills)
	if bomb_clear_active:
		return

	var guaranteed_drop := (
		guaranteed_drop_kills > 0
		and enemies_defeated % guaranteed_drop_kills == 0
	)

	if guaranteed_drop or randf() <= drop_chance:
		_spawn_power_up(drop_position)


func _on_enemy_hit() -> void:
	hit_sound.play()


func _award_combo_score(base_points: int) -> void:
	combo_count += 1
	combo_time_remaining = combo_window
	var multiplier := minf(3.0, 1.0 + floorf(float(combo_count) / 5.0) * 0.25)
	highest_combo = maxi(highest_combo, combo_count)
	score += roundi(float(base_points) * multiplier)
	hud.set_combo(combo_count, multiplier)
	if combo_count >= 25:
		_show_achievement("combo_25", "MEDAL EARNED\n25 ENEMY COMBO")


func _check_score_medals() -> void:
	for milestone in [25000, 50000, 75000, 100000]:
		if score >= milestone:
			_show_achievement("score_%d" % milestone, "MEDAL EARNED\n%d POINTS" % milestone)


func _show_achievement(achievement_id: String, message: String) -> void:
	if GameData.unlock_achievement(achievement_id):
		hud.show_tip(message, 3.0)


func _reset_combo() -> void:
	combo_count = 0
	combo_time_remaining = 0.0
	hud.set_combo(0, 1.0)


# ---------------------------------------------------------
# BOSS ENCOUNTER
# ---------------------------------------------------------

func _check_boss_milestone() -> void:
	if boss_active:
		return

	if score < next_boss_milestone:
		return

	if boss_scene == null:
		push_warning(
			"Boss milestone reached, but boss_scene is not assigned."
		)
		return

	# Set this immediately to prevent another score update
	# from spawning a second boss.
	boss_active = true

	call_deferred("_begin_boss_encounter")


func _begin_boss_encounter() -> void:
	timer.stop()
	player_hit_during_boss = false
	_prepare_player_for_boss()
	hud.show_boss_warning()
	await get_tree().create_timer(boss_warning_duration, false).timeout
	hud.hide_boss_warning()

	if player == null or not is_instance_valid(player):
		boss_active = false
		return

	_spawn_boss()


func _get_level_title(map_id: String) -> String:
	match map_id:
		"grassland":
			return "THE FRENCH COUNTRYSIDE"
		"desert":
			return "THE NORTH AFRICAN FRONT"
		_:
			return "THE ENGLISH CHANNEL"


func _spawn_boss() -> void:
	if boss_scene == null:
		boss_active = false
		return

	# Stop ordinary enemy spawning.
	timer.stop()

	# Remove remaining normal enemies before the boss enters.
	_clear_normal_enemies()

	var boss = boss_scene.instantiate()

	if boss == null:
		push_error("The boss scene could not be instantiated.")

		boss_active = false
		timer.start()
		return

	current_boss = boss
	_apply_boss_progression(boss)

	var screen_center_x := (
		get_viewport_rect().size.x / 2.0
	)

	boss.global_position = Vector2(
		screen_center_x,
		boss_spawn_y
	)

	# The boss uses a different kill callback.
	boss.killed.connect(_on_boss_killed)
	boss.hit.connect(_on_enemy_hit)
	boss.bullet_fired.connect(_on_boss_bullet_fired)
	boss.health_changed.connect(hud.show_boss_health)
	boss.battle_started.connect(_on_boss_battle_started.bind(boss))

	enemy_container.add_child(boss)


func _on_boss_battle_started(boss: BossEnemy) -> void:
	if boss == current_boss and is_instance_valid(boss):
		hud.show_boss_health(boss.hp, boss.max_hp)


func _prepare_player_for_boss() -> void:
	if player == null or not is_instance_valid(player):
		return

	if player.current_lives < player.max_lives:
		player.heal(1)
	else:
		player.activate_shield()


func _apply_boss_progression(boss: BossEnemy) -> void:
	var progression_hp := mini(50, 35 + bosses_defeated * 5)
	var shots_per_second: float = 1.0 / player.rate_of_fire
	if player.default_twin_cannons:
		shots_per_second *= 2.0
	var damage_ratio := shots_per_second / 5.0
	var plane_health_modifier := clampf(pow(damage_ratio, 0.35), 0.8, 1.2)
	var mobility_modifier := clampf(float(player.speed) / 300.0, 0.85, 1.1)

	boss.hp = clampi(
		int(round(float(progression_hp) * plane_health_modifier)),
		24,
		50
	)
	boss.attack_interval = maxf(1.45, 1.9 - bosses_defeated * 0.12)
	boss.phase_two_attack_interval = maxf(0.95, 1.2 - bosses_defeated * 0.07)
	boss.bullet_speed = minf(325.0, 245.0 + bosses_defeated * 15.0) * mobility_modifier
	boss.phase_two_bullet_speed = minf(350.0, 300.0 + bosses_defeated * 12.0) * mobility_modifier
	boss.movement_range = minf(175.0, 155.0 + bosses_defeated * 5.0)
	boss.movement_frequency = minf(1.35, 1.05 + bosses_defeated * 0.07)


func _on_boss_bullet_fired(
	bullet_scene: PackedScene,
	location: Vector2,
	direction: Vector2,
	bullet_speed: float
) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = location
	bullet.setup(direction, bullet_speed)
	bullet_container.add_child(bullet)


func _clear_normal_enemies() -> void:
	for enemy in enemy_container.get_children():
		if enemy == current_boss:
			continue

		enemy.queue_free()


func _on_boss_killed(points: int, drop_position: Vector2) -> void:
	if not boss_active:
		return

	explode_sound.play()
	_start_screen_shake(0.45, 10.0)

	# Keep boss_active true while adding the reward.
	# This prevents a V-formation from spawning immediately
	# because of the boss reward.
	score += points
	if not player_hit_during_boss:
		_show_achievement("flawless_boss", "MEDAL EARNED\nFLAWLESS BOSS")
	enemies_defeated += 1
	hud.set_kill_progress(enemies_defeated, guaranteed_drop_kills)
	_spawn_power_up(drop_position)
	if player != null and is_instance_valid(player):
		player.heal(1)
	hud.hide_boss_health()

	# Move the next boss milestone forward.
	next_boss_milestone += boss_score_interval

	# Increase difficulty after every defeated boss.
	difficulty_multiplier += difficulty_increase_per_boss
	bosses_defeated += 1

	current_boss = null
	boss_active = false

	# Skip any formation milestone passed by the boss reward.
	_advance_formation_milestone()
	if bosses_defeated >= mission_boss_target and not mission_milestone_shown:
		mission_milestone_shown = true
		call_deferred("_show_mission_milestone")
		return

	timer.start()


func _show_mission_milestone() -> void:
	timer.stop()
	_clear_container(enemy_container)
	_clear_container(bullet_container)
	_clear_container(power_up_container)
	if player != null and is_instance_valid(player):
		player.controls_enabled = false
		player.process_mode = Node.PROCESS_MODE_ALWAYS
	mission_complete.set_mission_target(mission_boss_target)
	mission_complete.visible = true
	get_tree().paused = true


func _on_continue_endless_requested() -> void:
	mission_complete.visible = false
	if player != null and is_instance_valid(player):
		player.controls_enabled = true
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = false
	timer.start()
	hud.show_endless_ribbon()


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _on_finish_mission_requested() -> void:
	mission_complete.visible = false
	timer.stop()
	hud.visible = false
	engine_sound.stop()
	var leaderboard_rank := GameData.submit_score(score)
	if bombs_used == 0:
		_show_achievement("no_bombs", "MEDAL EARNED\nNO BOMBS USED")
	high_score = GameData.get_high_score()
	gos.show_results(score, leaderboard_rank, true, _get_run_stats())
	gos.visible = true
	get_tree().paused = true


func _advance_formation_milestone() -> void:
	while next_formation_milestone <= score:
		next_formation_milestone += formation_score_interval


# ---------------------------------------------------------
# V-FORMATION
# ---------------------------------------------------------

func _check_formation_milestone() -> void:
	if boss_active:
		return

	if formation_score_interval <= 0:
		return

	if score < next_formation_milestone:
		return

	spawn_v_formation()
	next_formation_milestone += formation_score_interval


func spawn_v_formation() -> void:
	if boss_active:
		return

	if enemy_scenes.is_empty():
		return

	var diver_scene: PackedScene = null

	for scene in enemy_scenes:
		if "diver" in scene.resource_path.to_lower():
			diver_scene = scene
			break

	if diver_scene == null:
		diver_scene = enemy_scenes.pick_random()

	var screen_center_x := (
		get_viewport_rect().size.x / 2.0
	)

	var spawn_root_pos := Vector2(
		screen_center_x,
		spawn_y - 100.0
	)

	var formation_offsets = V_FORMATION_OFFSETS
	if current_map_id == "grassland":
		formation_offsets = COLUMN_OFFSETS
	elif current_map_id == "desert":
		formation_offsets = DIAGONAL_OFFSETS

	for offset in formation_offsets:
		var enemy = diver_scene.instantiate()

		_apply_enemy_difficulty(enemy)

		enemy.global_position = spawn_root_pos + offset
		enemy.modulate = _get_level_enemy_tint()

		enemy.killed.connect(_on_enemy_killed.bind(formation_drop_chance))
		enemy.hit.connect(_on_enemy_hit)

		enemy_container.add_child(enemy)


# ---------------------------------------------------------
# PLAYER DEATH
# ---------------------------------------------------------

func _on_player_killed() -> void:
	if game_over_pending:
		return
	game_over_pending = true
	timer.stop()
	boss_active = false
	hud.hide_boss_warning()
	hud.hide_boss_health()
	hud.visible = false
	pause_menu.close()
	_clear_container(enemy_container)
	_clear_container(bullet_container)
	_clear_container(power_up_container)

	engine_sound.stop()
	bg_sound.stop()
	explode_sound.play()

	var leaderboard_rank := GameData.submit_score(score)
	high_score = GameData.get_high_score()
	gos.show_results(score, leaderboard_rank, false, _get_run_stats())
	get_tree().paused = true

	await get_tree().create_timer(1.2, true).timeout

	gos.visible = true


func _on_player_lives_changed(current_lives: int, max_lives: int) -> void:
	hud.set_lives(current_lives, max_lives)
	if current_lives < last_player_lives:
		_reset_combo()
		if GameData.mark_guidance_seen("lives"):
			hud.show_tip("HEART LOST\nBRIEF INVINCIBILITY ACTIVE")
	last_player_lives = current_lives


func _on_player_hit_received(_blocked_by_shield: bool) -> void:
	if boss_active:
		player_hit_during_boss = true


# ---------------------------------------------------------
# POWER-UPS
# ---------------------------------------------------------

func _spawn_power_up(drop_position: Vector2) -> void:
	if power_up_scene == null or player == null or not is_instance_valid(player):
		return

	var power_up = power_up_scene.instantiate()
	power_up.power_up_type = _pick_power_up_type()
	last_power_up_type = power_up.power_up_type
	power_up.global_position = drop_position
	power_up_container.add_child(power_up)
	if GameData.mark_guidance_seen("power_ups"):
		hud.show_tip("POWER-UP SPOTTED\nCOLLECT IT BEFORE IT ESCAPES")


func _pick_power_up_type() -> String:
	var weighted_types := [
		{"type": PowerUp.HEART, "weight": 25.0 if player.current_lives < player.max_lives else 0.0},
		{"type": PowerUp.RAPID_FIRE, "weight": 10.0},
		{"type": PowerUp.SPREAD_SHOT, "weight": 25.0},
		{"type": PowerUp.SHIELD, "weight": 20.0},
		{"type": PowerUp.TWIN_CANNONS, "weight": 15.0},
		{"type": PowerUp.BOMB, "weight": 5.0}
	]
	var total_weight := 0.0

	for entry in weighted_types:
		if entry.type == last_power_up_type:
			entry.weight *= 0.15
		total_weight += entry.weight

	var roll := randf() * total_weight

	for entry in weighted_types:
		roll -= entry.weight
		if roll <= 0.0:
			return entry.type

	return PowerUp.SPREAD_SHOT


func _on_player_bomb_requested() -> void:
	bombs_used += 1
	_start_screen_shake(0.35, 8.0)
	bomb_clear_active = true
	for enemy in enemy_container.get_children():
		if enemy == current_boss:
			enemy.take_damage(5)
		else:
			enemy.take_damage(9999)
	bomb_clear_active = false


func _start_screen_shake(duration: float, strength: float) -> void:
	shake_time_remaining = maxf(shake_time_remaining, duration)
	shake_strength = maxf(shake_strength, strength)


func _get_run_stats() -> Dictionary:
	return {
		"enemies": enemies_defeated,
		"combo": highest_combo,
		"bosses": bosses_defeated,
		"time": run_time
	}


# ---------------------------------------------------------
# MAP SELECTION
# ---------------------------------------------------------

func _apply_selected_map(map_id: String) -> void:
	pb.scroll_offset = Vector2.ZERO
	background_sprite.position = Vector2.ZERO
	map_effects.set_effect(map_id)

	match map_id:
		"grassland":
			_apply_square_map(GRASSLAND_TEXTURE)
		"desert":
			_apply_square_map(DESERT_TEXTURE)
		_:
			_apply_square_map(OCEAN_TEXTURE)


func _apply_square_map(map_texture: Texture2D) -> void:
	var viewport_width := get_viewport_rect().size.x
	var map_scale := viewport_width / float(map_texture.get_width())
	var tile_height := map_texture.get_height() * map_scale

	background_sprite.texture = map_texture
	background_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	background_sprite.region_enabled = true
	background_sprite.region_rect = Rect2(
		0,
		0,
		map_texture.get_width(),
		map_texture.get_height() * 3
	)
	background_sprite.scale = Vector2(map_scale, map_scale)

	background_layer.motion_mirroring = Vector2(0, tile_height)


func _scroll_background(delta: float) -> void:
	if background_sprite.texture == null:
		return
	var region := background_sprite.region_rect
	var texture_height := float(background_sprite.texture.get_height())
	var texture_scroll := delta * parallax_scroll_speed / maxf(background_sprite.scale.y, 0.001)
	region.position.y = fposmod(region.position.y - texture_scroll, texture_height)
	background_sprite.region_rect = region


# ---------------------------------------------------------
# EASTER EGG
# ---------------------------------------------------------

func _update_easter_buffer(action: String) -> void:
	if is_easter_playing:
		return

	easter_buffer.append(action)

	if easter_buffer.size() > EASTER_SEQUENCE.size():
		easter_buffer.remove_at(0)

	if easter_buffer == EASTER_SEQUENCE:
		_trigger_easter_egg()
		easter_buffer.clear()


func _trigger_easter_egg() -> void:
	is_easter_playing = true
	easter_sound.play()

	await get_tree().create_timer(6, false).timeout

	var enemies = enemy_container.get_children()

	for enemy in enemies:
		if enemy.has_method("die"):
			enemy.die()

	score += easter_egg_score_bonus
	is_easter_playing = false
