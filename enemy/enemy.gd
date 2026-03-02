class_name Enemy
extends Area2D

signal killed(points)
signal hit

@export var speed: float = 150
@export var hp: int = 1
@export var points: int = 50

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var explosion: AnimatedSprite2D = $Explosion

var is_dying := false

func _ready() -> void:
	explosion.visible = false

func _physics_process(delta: float) -> void:
	if is_dying:
		return
	global_position.y += speed * delta

func take_damage(amount: int) -> void:
	if is_dying:
		return

	hp -= amount
	if hp <= 0:
		killed.emit(points)
		die()
	else:
		hit.emit()

func die() -> void:
	is_dying = true

	# Disable enemy visuals and collision
	sprite.visible = false
	collision.disabled = true

	# Play explosion
	explosion.visible = true
	explosion.play("explode")

	# Remove enemy after explosion finishes
	explosion.animation_finished.connect(_on_explosion_finished)

func _on_explosion_finished() -> void:
	queue_free()

func _on_body_entered(body):
	if body is Player:
		body.die()
		die()

func _on_visible_on_screen_notifier_2d_screen_exited():
	if not is_dying:
		queue_free()
