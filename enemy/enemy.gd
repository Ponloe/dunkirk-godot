class_name Enemy
extends Area2D

signal killed(points)

@export var speed: float = 150
@export var hp: int = 1 
@export var points: int = 50

func _physics_process(delta: float) -> void:
	global_position.y += speed * delta 

func die(): 
	queue_free()

func _on_body_entered(body):
	if body is Player:
		body.die()
		die()

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free() 

func take_damage(amount: int) -> void: 
	hp -= amount 
	if hp <= 0:
		killed.emit(points)
		die()
