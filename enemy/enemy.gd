class_name Enemy
extends Area2D

signal killed(points, drop_position)
signal hit

@export var speed: float = 150
@export var hp: int = 1
@export var points: int = 50
@export var type_tint := Color.WHITE

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var explosion: AnimatedSprite2D = $Explosion

var is_dying := false

func _ready() -> void:
	explosion.visible = false
	sprite.self_modulate = type_tint

func _physics_process(delta: float) -> void:
	if is_dying:
		return
	
	global_position.y += speed * delta

func take_damage(amount: int) -> void:
	if is_dying:
		return

	hp -= amount
	
	if hp <= 0:
		killed.emit(points, global_position)
		die()
	else:
		_flash_hit()
		hit.emit()


func apply_support_boost(speed_multiplier := 1.12) -> bool:
	if is_dying or has_meta("support_boosted"):
		return false
	set_meta("support_boosted", true)
	speed *= speed_multiplier
	sprite.modulate = Color(0.72, 1.0, 0.7, 1.0)
	var tween := create_tween()
	var original_scale := sprite.scale
	tween.tween_property(sprite, "scale", original_scale * 1.08, 0.12)
	tween.tween_property(sprite, "scale", original_scale, 0.16)
	return true


func _flash_hit() -> void:
	if not is_instance_valid(sprite):
		return

	sprite.self_modulate = Color(2.2, 2.2, 2.2, 1.0)
	var tween := create_tween()
	tween.tween_property(sprite, "self_modulate", type_tint, 0.09)

func die() -> void:
	if is_dying:
		return

	is_dying = true

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	sprite.visible = false
	collision.set_deferred("disabled", true)

	explosion.visible = true
	explosion.speed_scale = 1.05
	explosion.play("explode")

	if not explosion.animation_finished.is_connected(_on_explosion_finished):
		explosion.animation_finished.connect(_on_explosion_finished)

func _on_explosion_finished() -> void:
	queue_free()

func _on_body_entered(body):
	if is_dying:
		return

	if body is Player:
		body.take_hit()
		die()

func _on_visible_on_screen_notifier_2d_screen_exited():
	if not is_dying:
		queue_free()
