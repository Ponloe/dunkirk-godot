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
	if is_dying:
		return

	is_dying = true

	monitoring = false
	monitorable = false

	sprite.visible = false
	collision.set_deferred("disabled", true)

	explosion.visible = true
	explosion.play("explode")

	if not explosion.animation_finished.is_connected(_on_explosion_finished):
		explosion.animation_finished.connect(_on_explosion_finished)

func _on_explosion_finished() -> void:
	queue_free()

func _on_body_entered(body):
	if is_dying:
		return

	if body is Player:
		body.die()
		die()

func _on_visible_on_screen_notifier_2d_screen_exited():
	if not is_dying:
		queue_free()
