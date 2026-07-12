extends Node2D

@export var enemy_scenes: Array[PackedScene] = []

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

@export var formation_score_interval := 1000
@export var spawn_x_min := 50.0
@export var spawn_x_max := 500.0
@export var spawn_y := -50.0
@export var minimum_spawn_wait_time := 0.5
@export var spawn_wait_acceleration := 0.5
@export var parallax_scroll_speed := 100.0
@export var easter_egg_score_bonus := 5000

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
var actions_to_check = ["ui_up", "ui_down", "ui_left", "ui_right"]
var is_easter_playing := false

var next_formation_milestone = formation_score_interval
var player = null
var high_score := 0

var score := 0:
	set(value):
		score = value
		hud.score = score

		if score >= next_formation_milestone:
			spawn_v_formation()
			next_formation_milestone += formation_score_interval

func _ready() -> void:
	next_formation_milestone = formation_score_interval

	main_menu.start_game.connect(_on_main_menu_start_game)

	bg_sound.play()

	process_mode = Node.PROCESS_MODE_ALWAYS
	bg_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	engine_sound.stop()
	timer.stop()

	var save_file = FileAccess.open("user://save.data", FileAccess.READ)
	if save_file != null:
		high_score = save_file.get_32()
	else:
		high_score = 0

	score = 0

	main_menu.visible = true
	get_tree().paused = true

func _on_main_menu_start_game(selected_player_scene: PackedScene) -> void:
	if selected_player_scene == null:
		push_error("No player scene selected. Check MainMenu exported player scenes.")
		return

	get_tree().paused = false

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
	var save_file = FileAccess.open("user://save.data", FileAccess.WRITE)
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
		if timer.wait_time > minimum_spawn_wait_time:
			timer.wait_time = max(minimum_spawn_wait_time, timer.wait_time - delta * spawn_wait_acceleration)

		pb.scroll_offset.y += delta * parallax_scroll_speed

func _on_player_bullet_shot(bullet_scene, location) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = location
	bullet_container.add_child(bullet)
	gun_sound.play()

func _on_enemy_spawn_timer_timeout() -> void:
	var e = enemy_scenes.pick_random().instantiate()
	e.global_position = Vector2(randf_range(spawn_x_min, spawn_x_max), spawn_y)
	e.killed.connect(_on_enemy_killed)
	e.hit.connect(_on_enemy_hit)
	enemy_container.add_child(e)

func _on_enemy_killed(points) -> void:
	hit_sound.play()
	score += points

	if score > high_score:
		high_score = score

func _on_enemy_hit() -> void:
	hit_sound.play()

func _on_player_killed() -> void:
	engine_sound.stop()
	bg_sound.stop()
	explode_sound.play()

	gos.set_score(score)
	gos.set_high_score(high_score)
	save_game()

	await get_tree().create_timer(1.5).timeout
	gos.visible = true

func spawn_v_formation() -> void:
	var diver_scene = null

	for scene in enemy_scenes:
		if "diver" in scene.resource_path.to_lower():
			diver_scene = scene
			break

	if not diver_scene:
		diver_scene = enemy_scenes.pick_random()

	var screen_center_x = get_viewport_rect().size.x / 2.0
	var spawn_root_pos = Vector2(screen_center_x, spawn_y - 100.0)

	for offset in V_FORMATION_OFFSETS:
		var e = diver_scene.instantiate()
		e.global_position = spawn_root_pos + offset

		e.killed.connect(_on_enemy_killed)
		e.hit.connect(_on_enemy_hit)

		enemy_container.add_child(e)

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
	for e in enemies:
		if e.has_method("die"):
			e.die()

	score += easter_egg_score_bonus
	is_easter_playing = false
