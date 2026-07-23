extends Enemy

signal bullet_fired(bullet_scene, location, direction, bullet_speed)
@export var enemy_bullet_scene: PackedScene = preload("res://enemy/enemy_bullet.tscn")
@export var attack_interval := 2.4
var cooldown := 1.2


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	super._physics_process(delta)
	cooldown -= delta
	if cooldown > 0.0:
		return
	cooldown = attack_interval
	var target := get_tree().get_first_node_in_group("player") as Player
	if target != null:
		bullet_fired.emit(enemy_bullet_scene, global_position + Vector2(0, 35), global_position.direction_to(target.global_position), 210.0)
