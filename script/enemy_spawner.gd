extends Node2D

@export var enemy_scene: PackedScene # Drag enemy.tscn here!

func _ready():
	# Connect the timer signal in code (or use the editor node tab)
	$Timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout():
	spawn_enemy()

func spawn_enemy():
	if enemy_scene == null:
		return
		
	# 1. Create the enemy
	var enemy = enemy_scene.instantiate()
	
	# 2. Pick a random X position
	# We get the screen width so we spawn within bounds
	var screen_width = get_viewport_rect().size.x
	var random_x = randf_range(50, screen_width - 50) # Keep 50px buffer from edges
	
	# 3. Set position (Start slightly above the screen: Y = -50)
	enemy.position = Vector2(random_x, -50)
	
	# 4. Add to the Game scene
	# We add it to the 'owner' (Game) so it doesn't move with the spawner if the spawner moves
	add_child(enemy)
