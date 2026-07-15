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


@onready var player_spawn_pos = $PlayerSpawnPos
@onready var bullet_container = $BulletContainer
@onready var timer = $EnemySpawnTimer
@onready var enemy_container = $EnemyContainer
@onready var power_up_container = $PowerUpContainer

@onready var main_menu = $UILayer/MainMenu
@onready var hud = $UILayer/HUD
@onready var gos = $UILayer/GameOverScreen
@onready var pb = $ParallaxBackground
@onready var background_layer: ParallaxLayer = $ParallaxBackground/ParallaxLayer
@onready var background_sprite: Sprite2D = $ParallaxBackground/ParallaxLayer/cloud
@onready var map_effects: Node2D = $MapEffects

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
var next_boss_milestone := 2000

var boss_active := false
var current_boss = null

var difficulty_multiplier := 1.0
var player = null
var high_score := 0
var enemies_defeated := 0
var last_power_up_type := ""
var current_map_id := "ocean"
var wave_index := 0


var score := 0:
	set(value):
		score = value
		hud.score = score

		if score > high_score:
			high_score = score

		# Boss is checked first so a formation does not spawn
		# at the same milestone as a boss.
		_check_boss_milestone()
		_check_formation_milestone()


func _ready() -> void:
	next_formation_milestone = formation_score_interval
	next_boss_milestone = first_boss_score

	main_menu.start_game.connect(_on_main_menu_start_game)

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
	player.global_position = player_spawn_pos.global_position

	player.bullet_shot.connect(_on_player_bullet_shot)
	player.killed.connect(_on_player_killed)
	player.lives_changed.connect(_on_player_lives_changed)
	player.power_up_started.connect(hud.show_power_up)
	player.power_up_ended.connect(hud.hide_power_up)
	player.bomb_requested.connect(_on_player_bomb_requested)

	add_child(player)
	hud.set_lives(player.current_lives, player.max_lives)

	engine_sound.play()
	timer.wait_time = wave_interval
	timer.start()


func save_game() -> void:
	var save_file = FileAccess.open(
		"user://save.data",
		FileAccess.WRITE
	)

	if save_file != null:
		save_file.store_32(high_score)


func _process(delta: float) -> void:
	var focused_control := get_viewport().gui_get_focus_owner()
	var is_entering_text := (
		focused_control is LineEdit
		or focused_control is TextEdit
	)

	if not is_entering_text:
		if Input.is_action_just_pressed("quit"):
			get_tree().reload_current_scene()

		elif Input.is_action_just_pressed("reset"):
			get_tree().reload_current_scene()

		for action in actions_to_check:
			if Input.is_action_just_pressed(action):
				_update_easter_buffer(action)

	if not get_tree().paused:
		if not boss_active:
			if timer.wait_time > minimum_spawn_wait_time:
				timer.wait_time = max(
					minimum_spawn_wait_time,
					timer.wait_time -
					delta *
					spawn_wait_acceleration *
					difficulty_multiplier
				)


	# Keep the seamless battlefield moving behind the paused menu screens.
	pb.scroll_offset.y += delta * parallax_scroll_speed


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
			pattern_names = ["columns", "staggered", "v"]
		"desert":
			pattern_names = ["diagonal", "zigzag", "line"]
		_:
			pattern_names = ["v", "line", "patrol"]

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
	elif pattern in ["patrol", "zigzag", "staggered"]:
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

	enemy.points = max(
		1,
		roundi(enemy.points * difficulty_multiplier)
	)


func _on_enemy_killed(
	points: int,
	drop_position: Vector2,
	drop_chance: float
) -> void:
	hit_sound.play()
	score += points
	enemies_defeated += 1
	hud.set_kill_progress(enemies_defeated, guaranteed_drop_kills)

	var guaranteed_drop := (
		guaranteed_drop_kills > 0
		and enemies_defeated % guaranteed_drop_kills == 0
	)

	if guaranteed_drop or randf() <= drop_chance:
		_spawn_power_up(drop_position)


func _on_enemy_hit() -> void:
	hit_sound.play()


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
	hud.show_boss_warning()
	await get_tree().create_timer(boss_warning_duration).timeout
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

	enemy_container.add_child(boss)
	hud.show_boss_health(boss.hp, boss.max_hp)


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

	hit_sound.play()

	# Keep boss_active true while adding the reward.
	# This prevents a V-formation from spawning immediately
	# because of the boss reward.
	score += points
	enemies_defeated += 1
	hud.set_kill_progress(enemies_defeated, guaranteed_drop_kills)
	_spawn_power_up(drop_position)
	hud.hide_boss_health()

	# Move the next boss milestone forward.
	next_boss_milestone += boss_score_interval

	# Increase difficulty after every defeated boss.
	difficulty_multiplier += difficulty_increase_per_boss

	current_boss = null
	boss_active = false

	# Skip any formation milestone passed by the boss reward.
	_advance_formation_milestone()

	timer.start()


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
	timer.stop()
	hud.hide_boss_warning()
	hud.hide_boss_health()
	hud.visible = false

	engine_sound.stop()
	bg_sound.stop()
	explode_sound.play()

	var leaderboard_rank := GameData.submit_score(score)
	high_score = GameData.get_high_score()
	gos.show_results(score, leaderboard_rank)

	await get_tree().create_timer(1.5).timeout

	gos.visible = true
	get_tree().paused = true


func _on_player_lives_changed(current_lives: int, max_lives: int) -> void:
	hud.set_lives(current_lives, max_lives)


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
	for enemy in enemy_container.get_children():
		if enemy == current_boss:
			enemy.take_damage(5)
		else:
			enemy.take_damage(9999)


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

	await get_tree().create_timer(6).timeout

	var enemies = enemy_container.get_children()

	for enemy in enemies:
		if enemy.has_method("die"):
			enemy.die()

	score += easter_egg_score_bonus
	is_easter_playing = false
