extends Node2D

@export var enemy_scenes: Array[PackedScene] = []

@onready var player_spawn_pos = $PlayerSpawnPos
@onready var bullet_container = $BulletContainer
@onready var timer = $EnemySpawnTimer
@onready var enemy_container = $EnemyContainer

@onready var main_menu = $UILayer/MainMenu
@onready var hud  = $UILayer/HUD 
@onready var gos = $UILayer/GameOverScreen
@onready var pb = $ParallaxBackground

@onready var gun_sound = $SFX/GunSound
@onready var engine_sound = $SFX/EngineSound
@onready var hit_sound = $SFX/HitSound
@onready var explode_sound = $SFX/ExplodeSound
@onready var bg_sound = $SFX/BgSound

var player = null 
var score := 0:
	set(value):
		score = value     
		hud.score = score

var high_score 

var scroll_speed = 100

func _ready():
	main_menu.start_game.connect(_on_main_menu_start_game)
	bg_sound.play()
	
	process_mode = Node.PROCESS_MODE_PAUSABLE
	bg_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	engine_sound.stop()
	timer.stop()
	
	var save_file = FileAccess.open("user://save.data", FileAccess.READ)
	if save_file != null: 
		high_score = save_file.get_32()
	else: 
		high_score = 0
	
	score = 0
	player = get_tree().get_first_node_in_group("player")
	player.global_position = player_spawn_pos.global_position
	player.bullet_shot.connect(_on_player_bullet_shot)
	player.killed.connect(_on_player_killed)
	
	main_menu.visible = true
	get_tree().paused = true
	
func _on_main_menu_start_game():
	get_tree().paused = false
	engine_sound.play()
	timer.start()
	
func save_game(): 
	var save_file = FileAccess.open("user://save.data", FileAccess.WRITE)
	save_file.store_32(high_score)
	

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	elif Input.is_action_just_pressed("reset"):
		get_tree().reload_current_scene()

	if not get_tree().paused:
		if timer.wait_time > 0.5: 
			timer.wait_time -= delta * 0.5
		elif timer.wait_time < 0.45:
			timer.wait_time -= 0.45
		
		pb.scroll_offset.y += delta * scroll_speed

func _on_player_bullet_shot(bullet_scene, location):
	var bullet = bullet_scene.instantiate()
	bullet.global_position =  location
	bullet_container.add_child(bullet)
	gun_sound.play()

func _on_enemy_spawn_timer_timeout():
	var e = enemy_scenes.pick_random().instantiate()
	e.global_position = Vector2(randf_range(50, 500), -50)
	e.killed.connect(_on_enemy_killed)
	e.hit.connect(_on_enemy_hit)
	enemy_container.add_child(e)

func _on_enemy_killed(points):
	hit_sound.play()
	score += points
	if score > high_score: 
		high_score = score 

func _on_enemy_hit():
	hit_sound.play()

func _on_player_killed():
	engine_sound.stop()
	bg_sound.stop()
	explode_sound.play()
	gos.set_score(score)
	gos.set_high_score(high_score)
	save_game()
	await get_tree().create_timer(1.5).timeout
	gos.visible = true
