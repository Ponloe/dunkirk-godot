extends Area2D

@export var speed: float = 500.0 # Bullets should be faster than the player

func _ready():
	# Connect the cleanup signal automatically
	# Make sure you added a VisibleOnScreenNotifier2D node to your bullet scene!
	var notifier = $VisibleOnScreenNotifier2D
	if notifier:
		notifier.screen_exited.connect(_on_screen_exited)
	
	# Connect the collision signal automatically
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# Move bullet UP (Negative Y)
	position.y -= speed * delta

# Called when the bullet leaves the screen view
func _on_screen_exited():
	queue_free() # Delete the bullet from memory

# Called when the bullet hits something (like an Enemy)
func _on_body_entered(body):
	if body.name == "Player":
		return # Ignore collision with the player who shot it
	
	# If the body has a function called 'take_damage', call it
	if body.has_method("take_damage"):
		body.take_damage()
		
	queue_free() # Destroy the bullet on impact


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	pass # Replace with function body.
