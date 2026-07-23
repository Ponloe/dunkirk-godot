extends Enemy

@export var tracking_strength := 2.2
var flight_direction := Vector2.DOWN


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	var target := get_tree().get_first_node_in_group("player") as Player
	if target != null:
		var desired := global_position.direction_to(target.global_position)
		flight_direction = flight_direction.lerp(desired, minf(1.0, tracking_strength * delta)).normalized()
	global_position += flight_direction * speed * delta
	rotation = flight_direction.angle() - PI / 2.0
