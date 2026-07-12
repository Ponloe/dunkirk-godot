extends Enemy

@export var turn_strength := 90.0
@export var turn_interval := 1.2
@export var max_bank_angle := 18.0
@export var horizontal_speed := 80.0

var direction := 1
var turn_timer := 0.0
var x_velocity := 0.0

func _ready():
	super()
	direction = [-1, 1].pick_random()

func _physics_process(delta):
	if is_dying:
		return

	turn_timer += delta

	if turn_timer >= turn_interval:
		turn_timer = 0.0
		direction *= -1

	var target_x_velocity = direction * horizontal_speed
	x_velocity = move_toward(x_velocity, target_x_velocity, turn_strength * delta)

	global_position.x += x_velocity * delta
	global_position.y += speed * delta

	var target_rotation = deg_to_rad(direction * max_bank_angle)
	rotation = lerp_angle(rotation, target_rotation, delta * 4.0)
