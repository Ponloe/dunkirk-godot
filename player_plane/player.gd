extends CharacterBody2D

# EXPORT VARIABLES (These appear in the Inspector)
# Drag your bullet.tscn file into this slot in the Inspector!
@export var bullet_scene: PackedScene 
@export var speed: float = 300.0
@export var cooldown_time: float = 0.2 # Time between shots

# INTERNAL VARIABLES
var can_shoot: bool = true
var screen_size: Vector2

func _ready():
	# Get the screen size so we can stop the player from flying off
	screen_size = get_viewport_rect().size

func _physics_process(delta):
	player_movement()
	player_shooting()

func player_movement():
	# Input.get_vector handles diagonal movement perfectly (no speed boost)
	# Ensure you have "ui_up", "ui_down", "ui_left", "ui_right" mapped 
	# (These are mapped to Arrows by default in Godot)
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	velocity = direction * speed
	move_and_slide()
	
	# Clamp position so player stays on screen
	# We add a little buffer (16 pixels) so the sprite doesn't get cut off
	position.x = clamp(position.x, 16, screen_size.x - 16)
	position.y = clamp(position.y, 16, screen_size.y - 16)

func player_shooting():
	if Input.is_action_pressed("ui_accept") and can_shoot: # Default "ui_accept" is Spacebar
		shoot()

func shoot():
	if bullet_scene == null:
		print("ERROR: No Bullet Scene assigned in Inspector!")
		return
		
	# 1. Create the bullet
	var bullet_instance = bullet_scene.instantiate()
	
	# 2. Position it at the player's location
	# Optional: Add + Vector2(0, -20) to make it appear from the nose, not the center
	bullet_instance.global_position = global_position + Vector2(0, -20)
	
	# 3. Add it to the main scene (Root) so it moves independently of the player
	get_tree().root.add_child(bullet_instance)
	
	# 4. Handle Cooldown
	can_shoot = false
	await get_tree().create_timer(cooldown_time).timeout
	can_shoot = true
