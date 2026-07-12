extends Enemy
class_name BossEnemy

@export_category("Boss Movement")
@export var entry_target_y: float = 170.0
@export var horizontal_speed: float = 110.0
@export var movement_range: float = 170.0
@export var movement_frequency: float = 1.2

var movement_time: float = 0.0
var center_x: float
var has_entered: bool = false


func _ready() -> void:
	super._ready()

	center_x = get_viewport_rect().size.x / 2.0

	# Prevent the inherited off-screen notifier from deleting the boss
	# while it is entering from above.
	if has_node("VisibleOnScreenNotifier2D"):
		$VisibleOnScreenNotifier2D.process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	if not has_entered:
		_enter_battlefield(delta)
	else:
		_fly_boss_pattern(delta)


func _enter_battlefield(delta: float) -> void:
	global_position.y = move_toward(
		global_position.y,
		entry_target_y,
		speed * delta
	)

	if global_position.y >= entry_target_y:
		global_position.y = entry_target_y
		center_x = global_position.x
		has_entered = true


func _fly_boss_pattern(delta: float) -> void:
	movement_time += delta

	# Wide and smooth side-to-side banking movement.
	var horizontal_offset := sin(
		movement_time * movement_frequency
	) * movement_range

	global_position.x = center_x + horizontal_offset

	# Slight vertical movement makes the aircraft feel less static.
	global_position.y = entry_target_y + sin(
		movement_time * movement_frequency * 0.5
	) * 20.0
