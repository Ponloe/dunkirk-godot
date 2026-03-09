extends Enemy

@export var amplitude: float = 100.0 # How far left/right it goes
@export var frequency: float = 5.0  # How fast it sways

var time_passed: float = 0.0

func _physics_process(delta: float) -> void:
	if is_dying: return
	
	time_passed += delta
	# Horizontal movement based on Sine wave
	global_position.x += cos(time_passed * frequency) * amplitude * delta
	# Vertical movement (inherited speed)
	global_position.y += speed * delta
