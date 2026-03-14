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
@onready var easter_sound = $SFX/Easter


const V_FORMATION_OFFSETS = [
	Vector2(0, 0),      # The Lead (Tip of V)
	Vector2(-70, -60),  # Left Wing 1
	Vector2(70, -60),   # Right Wing 1
	Vector2(-140, -120),# Left Wing 2
	Vector2(140, -120)  # Right Wing 2
]

const EASTER_SEQUENCE = [
	"ui_up", "ui_up", "ui_down", "ui_down",
	"ui_left", "ui_right", "ui_left", "ui_right"
]
var easter_buffer: Array[String] = []
var actions_to_check = ["ui_up", "ui_down", "ui_left", "ui_right"]
var is_easter_playing := false

var next_formation_milestone = 1000

var player = null 
var score := 0:
	set(value):
		score = value     
		hud.score = score
		
		if score >= next_formation_milestone:
			spawn_v_formation()
			next_formation_milestone += 1000

var high_score 

var scroll_speed = 100

func _ready():
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
		get_tree().reload_current_scene()
	elif Input.is_action_just_pressed("reset"):
		get_tree().reload_current_scene()
	
	for action in actions_to_check:
		if Input.is_action_just_pressed(action):
			_update_easter_buffer(action)
		
		

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
	

func spawn_v_formation():
	var diver_scene = null
	for scene in enemy_scenes:
		if "diver" in scene.resource_path.to_lower():
			diver_scene = scene
			break
	
	if not diver_scene:
		diver_scene = enemy_scenes.pick_random()

	var screen_center_x = 275 
	var spawn_root_pos = Vector2(screen_center_x, -150)

	for offset in V_FORMATION_OFFSETS:
		var e = diver_scene.instantiate()
		e.global_position = spawn_root_pos + offset
		
		e.killed.connect(_on_enemy_killed)
		e.hit.connect(_on_enemy_hit)
		
		enemy_container.add_child(e)
		
func _update_easter_buffer(action: String):
	if is_easter_playing:
		return

	easter_buffer.append(action)
	
	if easter_buffer.size() > EASTER_SEQUENCE.size():
		easter_buffer.remove_at(0)
	
	if easter_buffer == EASTER_SEQUENCE:
		_trigger_easter_egg()
		easter_buffer.clear()

func _trigger_easter_egg():
	easter_sound.play()
	
	await get_tree().create_timer(6).timeout
	
	var enemies = enemy_container.get_children()
	for e in enemies:
		if e.has_method("die"):
			e.die() 
	
	score += 5000
	is_easter_playing = false
