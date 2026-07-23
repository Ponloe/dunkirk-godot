class_name Player
extends CharacterBody2D

signal bullet_shot(bullet_scene, location, direction)
signal killed
signal lives_changed(current_lives, max_lives)
signal power_up_started(power_up_type, duration)
signal power_up_ended(power_up_type)
signal shield_changed(active)
signal bomb_requested
signal hit_received(blocked_by_shield)

@export var speed := 300
@export var rate_of_fire := 0.2
@export_range(1, 5) var control_rating := 3
@export var max_lives := 3
@export var invincibility_duration := 1.5
@export var propeller_positions: Array[Vector2] = [Vector2(0, -45)]
@export var propeller_blade_length := 13.0
@export var default_twin_cannons := false
@export var screen_margin := Vector2(50.0, 58.0)

@onready var muzzle: Marker2D = $Muzzle
@onready var sprite: Sprite2D = $Sprite2D

var bullet_scene: PackedScene = preload("res://bullet.tscn")
var current_lives := 0
var shoot_cooldown := 0.0
var current_rate_of_fire := 0.2
var is_invincible := false
var is_dead := false
var rapid_fire_generation := 0
var spread_shot_generation := 0
var twin_cannons_generation := 0
var spread_shot_active := false
var twin_cannons_active := false
var shield_active := false
var visual_root: Node2D
var damage_effects: Node2D
var controls_enabled := true

const PROPELLER_SCRIPT := preload("res://player_plane/propeller.gd")


func _ready() -> void:
	current_lives = max_lives
	current_rate_of_fire = rate_of_fire
	visual_root = Node2D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	move_child(visual_root, 0)
	sprite.reparent(visual_root, false)
	_create_plane_shadow()
	_create_propellers()
	damage_effects = Node2D.new()
	damage_effects.set_script(preload("res://player_plane/damage_effects.gd"))
	add_child(damage_effects)


func _create_plane_shadow() -> void:
	var shadow := Node2D.new()
	shadow.set_script(preload("res://player_plane/plane_shadow.gd"))
	shadow.position = Vector2(0, 34)
	shadow.set("shadow_width", 42.0)
	shadow.set("shadow_height", 8.0)
	add_child(shadow)


func _create_propellers() -> void:
	for propeller_position in propeller_positions:
		var propeller := Node2D.new()
		propeller.set_script(PROPELLER_SCRIPT)
		propeller.position = propeller_position
		propeller.blade_length = propeller_blade_length
		visual_root.add_child(propeller)


func _process(delta: float) -> void:
	if is_dead:
		return

	shoot_cooldown = maxf(0.0, shoot_cooldown - delta)

	if controls_enabled and Input.is_action_pressed("shoot") and shoot_cooldown <= 0.0:
		shoot()
		shoot_cooldown = current_rate_of_fire

	if is_invincible:
		sprite.modulate.a = 0.35 if int(Time.get_ticks_msec() / 100) % 2 == 0 else 1.0

	var bank_target := clampf(-velocity.x / maxf(float(speed), 1.0) * 0.12, -0.12, 0.12)
	visual_root.rotation = lerp_angle(
		visual_root.rotation,
		bank_target,
		minf(1.0, delta * 10.0)
	)
	if controls_enabled:
		visual_root.position.y = lerpf(visual_root.position.y, 0.0, minf(1.0, delta * 8.0))
	else:
		visual_root.position.y = sin(Time.get_ticks_msec() * 0.003) * 2.5


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not controls_enabled:
		velocity = Vector2.ZERO
		return

	var direction := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).limit_length(1.0)

	var target_velocity := direction * speed
	var handling_response := lerpf(6.0, 18.0, float(control_rating - 1) / 4.0)
	velocity = velocity.move_toward(
		target_velocity,
		float(speed) * handling_response * delta
	)
	move_and_slide()
	var viewport_size := get_viewport_rect().size
	global_position = global_position.clamp(
		screen_margin,
		viewport_size - screen_margin
	)


func shoot() -> void:
	var origins: Array[Vector2] = [muzzle.global_position]
	var directions: Array[Vector2] = [Vector2.UP]

	if twin_cannons_active or default_twin_cannons:
		origins = [
			muzzle.global_position + Vector2(-18, 5),
			muzzle.global_position + Vector2(18, 5)
		]

	if spread_shot_active:
		directions = [
			Vector2.UP.rotated(deg_to_rad(-20)),
			Vector2.UP,
			Vector2.UP.rotated(deg_to_rad(20))
		]

	for origin in origins:
		for direction in directions:
			bullet_shot.emit(bullet_scene, origin, direction)


func take_hit() -> bool:
	if is_dead or is_invincible:
		return false

	if shield_active:
		shield_active = false
		shield_changed.emit(false)
		power_up_ended.emit(PowerUp.SHIELD)
		damage_effects.call("burst")
		hit_received.emit(true)
		return true

	current_lives = maxi(0, current_lives - 1)
	hit_received.emit(false)
	lives_changed.emit(current_lives, max_lives)
	damage_effects.call("set_smoke_active", current_lives == 1)

	if current_lives <= 0:
		die()
		return true

	is_invincible = true
	get_tree().create_timer(invincibility_duration, false).timeout.connect(_end_invincibility)
	return true


func heal(amount := 1) -> bool:
	if is_dead or current_lives >= max_lives:
		return false

	current_lives = mini(max_lives, current_lives + amount)
	lives_changed.emit(current_lives, max_lives)
	damage_effects.call("set_smoke_active", current_lives == 1)
	return true


func activate_rapid_fire(duration := 6.0, fire_rate_multiplier := 0.45) -> void:
	rapid_fire_generation += 1
	var activation_id := rapid_fire_generation
	current_rate_of_fire = maxf(0.05, rate_of_fire * fire_rate_multiplier)
	power_up_started.emit(PowerUp.RAPID_FIRE, duration)
	await get_tree().create_timer(duration, false).timeout

	if is_dead or activation_id != rapid_fire_generation:
		return

	current_rate_of_fire = rate_of_fire
	power_up_ended.emit(PowerUp.RAPID_FIRE)


func activate_spread_shot(duration := 8.0) -> void:
	spread_shot_generation += 1
	var activation_id := spread_shot_generation
	spread_shot_active = true
	power_up_started.emit(PowerUp.SPREAD_SHOT, duration)
	await get_tree().create_timer(duration, false).timeout

	if is_dead or activation_id != spread_shot_generation:
		return

	spread_shot_active = false
	power_up_ended.emit(PowerUp.SPREAD_SHOT)


func activate_twin_cannons(duration := 8.0) -> void:
	twin_cannons_generation += 1
	var activation_id := twin_cannons_generation
	twin_cannons_active = true
	power_up_started.emit(PowerUp.TWIN_CANNONS, duration)
	await get_tree().create_timer(duration, false).timeout

	if is_dead or activation_id != twin_cannons_generation:
		return

	twin_cannons_active = false
	power_up_ended.emit(PowerUp.TWIN_CANNONS)


func activate_shield() -> void:
	shield_active = true
	shield_changed.emit(true)
	power_up_started.emit(PowerUp.SHIELD, -1.0)


func activate_bomb() -> void:
	bomb_requested.emit()


func _end_invincibility() -> void:
	if is_dead:
		return

	is_invincible = false
	sprite.modulate.a = 1.0


func die() -> void:
	if is_dead:
		return

	is_dead = true
	killed.emit()
	queue_free()
