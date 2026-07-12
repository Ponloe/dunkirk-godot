extends Node2D

@export_category("Enemy Spawning")
@export var enemy_scenes: Array[PackedScene] = []
@export var spawn_x_min := 50.0
@export var spawn_x_max := 500.0
@export var spawn_y := -50.0
@export var minimum_spawn_wait_time := 0.5
@export var spawn_wait_acceleration := 0.5

@export_category("Formation")
@export var formation_score_interval := 1000

@export_category("Boss Encounter")
@export var boss_scene: PackedScene
@export var first_boss_score := 2000
@export var boss_score_interval := 2000
@export var boss_spawn_y := -150.0
@export var difficulty_increase_per_boss := 0.25

@export_category("Other Settings")
@export var parallax_scroll_speed := 100.0
@export var easter_egg_score_bonus := 5000


@onready var player_spawn_pos = $PlayerSpawnPos
@onready var bullet_container = $BulletContainer
@onready var timer = $EnemySpawnTimer
@onready var enemy_container = $EnemyContainer

@onready var main_menu = $UILayer/MainMenu
@onready var hud = $UILayer/HUD
@onready var gos = $UILayer/GameOverScreen
@onready var pb = $ParallaxBackground

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

const EASTER_SEQUENCE = [
	"ui_up", "ui_up", "ui_down", "ui_down",
	"ui_left", "ui_right", "ui_left", "ui_right"
]


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

	var save_file = FileAccess.open(
		"user://save.data",
		FileAccess.READ
	)

	if save_file != null:
		high_score = save_file.get_32()
	else:
		high_score = 0

	score = 0

	main_menu.visible = true
	get_tree().paused = true


func _on_main_menu_start_game(
	selected_player_scene: PackedScene
) -> void:
	if selected_player_scene == null:
		push_error(
			"No player scene selected. Check MainMenu exported player scenes."
		)
		return

	get_tree().paused = false

	score = 0
	difficulty_multiplier = 1.0

	boss_active = false
	current_boss = null

	next_formation_milestone = formation_score_interval
	next_boss_milestone = first_boss_score

	if player != null:
		player.queue_free()

	player = selected_player_scene.instantiate()
	player.global_position = player_spawn_pos.global_position
	add_child(player)

	player.bullet_shot.connect(_on_player_bullet_shot)
	player.killed.connect(_on_player_killed)

	engine_sound.play()
	timer.start()


func save_game() -> void:
	var save_file = FileAccess.open(
		"user://save.data",
		FileAccess.WRITE
	)

	if save_file != null:
		save_file.store_32(high_score)


func _process(delta: float) -> void:
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

		pb.scroll_offset.y += delta * parallax_scroll_speed


func _on_player_bullet_shot(
	bullet_scene: PackedScene,
	location: Vector2
) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = location
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

	var selected_scene: PackedScene = enemy_scenes.pick_random()
	var enemy = selected_scene.instantiate()

	_apply_enemy_difficulty(enemy)

	enemy.global_position = Vector2(
		randf_range(spawn_x_min, spawn_x_max),
		spawn_y
	)

	enemy.killed.connect(_on_enemy_killed)
	enemy.hit.connect(_on_enemy_hit)

	enemy_container.add_child(enemy)


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


func _on_enemy_killed(points: int) -> void:
	hit_sound.play()
	score += points


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

	call_deferred("_spawn_boss")


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

	enemy_container.add_child(boss)


func _clear_normal_enemies() -> void:
	for enemy in enemy_container.get_children():
		if enemy == current_boss:
			continue

		enemy.queue_free()


func _on_boss_killed(points: int) -> void:
	if not boss_active:
		return

	hit_sound.play()

	# Keep boss_active true while adding the reward.
	# This prevents a V-formation from spawning immediately
	# because of the boss reward.
	score += points

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

	for offset in V_FORMATION_OFFSETS:
		var enemy = diver_scene.instantiate()

		_apply_enemy_difficulty(enemy)

		enemy.global_position = spawn_root_pos + offset

		enemy.killed.connect(_on_enemy_killed)
		enemy.hit.connect(_on_enemy_hit)

		enemy_container.add_child(enemy)


# ---------------------------------------------------------
# PLAYER DEATH
# ---------------------------------------------------------

func _on_player_killed() -> void:
	timer.stop()

	engine_sound.stop()
	bg_sound.stop()
	explode_sound.play()

	gos.set_score(score)
	gos.set_high_score(high_score)

	save_game()

	await get_tree().create_timer(1.5).timeout

	gos.visible = true


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
