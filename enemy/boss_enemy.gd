extends Enemy
class_name BossEnemy

signal bullet_fired(bullet_scene, location, direction, bullet_speed)
signal health_changed(current_hp, max_hp)
signal battle_started

@export_category("Boss Movement")
@export var entry_target_y := 170.0
@export var movement_range := 170.0
@export var movement_frequency := 1.2

@export_category("Boss Attacks")
@export var enemy_bullet_scene: PackedScene = preload("res://enemy/enemy_bullet.tscn")
@export var attack_interval := 1.9
@export var phase_two_attack_interval := 1.2
@export var bullet_speed := 245.0
@export var phase_two_bullet_speed := 300.0

var movement_time := 0.0
var center_x := 0.0
var has_entered := false
var max_hp := 1
var attack_cooldown := 1.0
var attack_pattern_index := 0
var phase_two_announced := false


func _ready() -> void:
	super._ready()
	center_x = get_viewport_rect().size.x / 2.0
	max_hp = hp

	if has_node("VisibleOnScreenNotifier2D"):
		$VisibleOnScreenNotifier2D.process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(delta: float) -> void:
	if is_dying:
		return

	if not has_entered:
		_enter_battlefield(delta)
		return

	_fly_boss_pattern(delta)
	_process_attacks(delta)


func take_damage(amount: int) -> void:
	if not has_entered or is_dying:
		return

	super.take_damage(amount)
	if _is_phase_two() and not phase_two_announced and not is_dying:
		phase_two_announced = true
		_play_phase_change()

	if not is_dying:
		health_changed.emit(hp, max_hp)


func _enter_battlefield(delta: float) -> void:
	global_position.y = move_toward(global_position.y, entry_target_y, speed * delta)

	if global_position.y >= entry_target_y:
		global_position.y = entry_target_y
		center_x = global_position.x
		has_entered = true
		attack_cooldown = 1.35
		battle_started.emit()
		health_changed.emit(hp, max_hp)


func _fly_boss_pattern(delta: float) -> void:
	movement_time += delta
	var phase_speed := 1.35 if _is_phase_two() else 1.0
	var horizontal_offset := sin(movement_time * movement_frequency * phase_speed) * movement_range
	global_position.x = center_x + horizontal_offset
	global_position.y = entry_target_y + sin(movement_time * movement_frequency * 0.5) * 20.0


func _process_attacks(delta: float) -> void:
	attack_cooldown -= delta
	if attack_cooldown > 0.0:
		return

	if attack_pattern_index % 2 == 0:
		_fire_aimed_burst()
	else:
		_fire_fan()

	attack_pattern_index += 1
	attack_cooldown = phase_two_attack_interval if _is_phase_two() else attack_interval


func _fire_aimed_burst() -> void:
	var target := get_tree().get_first_node_in_group("player") as Player
	if target == null:
		return

	var aimed_direction := global_position.direction_to(target.global_position)
	var current_speed := phase_two_bullet_speed if _is_phase_two() else bullet_speed

	for angle in [-8.0, 0.0, 8.0]:
		bullet_fired.emit(
			enemy_bullet_scene,
			global_position + Vector2(0, 45),
			aimed_direction.rotated(deg_to_rad(angle)),
			current_speed
		)


func _fire_fan() -> void:
	var current_speed := phase_two_bullet_speed if _is_phase_two() else bullet_speed
	for angle in [-42.0, -21.0, 0.0, 21.0, 42.0]:
		bullet_fired.emit(
			enemy_bullet_scene,
			global_position + Vector2(0, 45),
			Vector2.DOWN.rotated(deg_to_rad(angle)),
			current_speed
		)


func _is_phase_two() -> bool:
	return hp <= max_hp / 2


func _play_phase_change() -> void:
	var original_scale := sprite.scale
	sprite.self_modulate = Color(1.8, 0.45, 0.3, 1.0)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", original_scale * 1.12, 0.14)
	tween.tween_property(sprite, "scale", original_scale, 0.2)
	tween.parallel().tween_property(sprite, "self_modulate", type_tint, 0.2)


func _on_body_entered(body: Node2D) -> void:
	if is_dying or not has_entered:
		return

	if body is Player:
		body.take_hit()
