extends Enemy

var boost_cooldown := 1.0


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	super._physics_process(delta)
	boost_cooldown -= delta
	if boost_cooldown > 0.0:
		return
	boost_cooldown = 2.0
	for ally in get_parent().get_children():
		if ally is Enemy and ally != self and global_position.distance_to(ally.global_position) < 150.0:
			ally.apply_support_boost()
