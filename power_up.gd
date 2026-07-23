class_name PowerUp
extends Area2D

signal collected(power_up_type)

const HEART := "heart"
const RAPID_FIRE := "rapid_fire"
const SPREAD_SHOT := "spread_shot"
const SHIELD := "shield"
const TWIN_CANNONS := "twin_cannons"
const BOMB := "bomb"

const POWER_UP_TEXTURES := {
	HEART: preload("res://assets/heart-removebg-preview.png"),
	RAPID_FIRE: preload("res://assets/rapid_fire-removebg-preview.png"),
	SPREAD_SHOT: preload("res://assets/spread_shot.png"),
	SHIELD: preload("res://assets/shield.png"),
	TWIN_CANNONS: preload("res://assets/twin_cannons.png"),
	BOMB: preload("res://assets/bomb.png")
}

@export_enum("heart", "rapid_fire", "spread_shot", "shield", "twin_cannons", "bomb") var power_up_type := HEART
@export var fall_speed := 115.0
@export var rapid_fire_duration := 6.0
@export var weapon_duration := 8.0
@export var rapid_fire_multiplier := 0.45
@export var magnet_range := 150.0
@export var magnet_speed := 210.0

@onready var sprite: Sprite2D = $Sprite2D

var elapsed := 0.0
var starting_x := 0.0


func _ready() -> void:
	starting_x = global_position.x
	sprite.texture = POWER_UP_TEXTURES.get(power_up_type, POWER_UP_TEXTURES[HEART])


func _physics_process(delta: float) -> void:
	elapsed += delta
	var target := get_tree().get_first_node_in_group("player") as Player
	if target != null and global_position.distance_to(target.global_position) <= magnet_range:
		global_position = global_position.move_toward(target.global_position, magnet_speed * delta)
	else:
		global_position.y += fall_speed * delta
		global_position.x = starting_x + sin(elapsed * 3.0) * 10.0
	sprite.rotation = sin(elapsed * 4.0) * 0.06
	if global_position.y > get_viewport_rect().size.y - 170.0:
		sprite.modulate.a = 0.35 if int(elapsed * 10.0) % 2 == 0 else 1.0

	if global_position.y > get_viewport_rect().size.y + 80.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return

	match power_up_type:
		HEART:
			body.heal(1)
		RAPID_FIRE:
			body.activate_rapid_fire(rapid_fire_duration, rapid_fire_multiplier)
		SPREAD_SHOT:
			body.activate_spread_shot(weapon_duration)
		SHIELD:
			body.activate_shield()
		TWIN_CANNONS:
			body.activate_twin_cannons(weapon_duration)
		BOMB:
			body.activate_bomb()

	collected.emit(power_up_type)
	queue_free()
