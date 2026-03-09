extends Enemy

@export var horizontal_speed: float = 100.0
var direction: int = 1 # 1 for right, -1 for left

func _ready() -> void:
	super._ready()
	# If spawned on the right half of screen, fly left. Else fly right.
	var screen_width = get_viewport_rect().size.x
	direction = -1 if global_position.x > screen_width / 2 else 1
	# Optional: Flip the sprite to face the direction
	sprite.flip_h = direction < 0

func _physics_process(delta: float) -> void:
	if is_dying: return
	
	global_position.x += horizontal_speed * direction * delta
	global_position.y += speed * delta
