extends Area2D

@export var speed := 270.0
var travel_direction := Vector2.DOWN


func setup(direction: Vector2, bullet_speed := 270.0) -> void:
	travel_direction = direction.normalized()
	speed = bullet_speed
	rotation = travel_direction.angle()


func _physics_process(delta: float) -> void:
	global_position += travel_direction * speed * delta

	var viewport_size := get_viewport_rect().size
	if (
		global_position.y > viewport_size.y + 60.0
		or global_position.y < -60.0
		or global_position.x < -60.0
		or global_position.x > viewport_size.x + 60.0
	):
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.take_hit()
		queue_free()
