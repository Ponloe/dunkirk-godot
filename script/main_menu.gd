extends CanvasLayer

func _ready():
	# 1. Freeze the game as soon as it loads
	get_tree().paused = true

# This is a helper function that actually starts the game
func start_the_game():
	# 2. Unfreeze the game
	get_tree().paused = false
	
	# 3. Hide the menu
	visible = false

# --- BUTTON SIGNALS ---

func _on_button_mission_pressed() -> void:
	start_the_game() 

func _on_button_endless_pressed() -> void:
	start_the_game()
