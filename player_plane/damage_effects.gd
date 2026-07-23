extends Node2D

var smoke_active := false
var spawn_cooldown := 0.0
var particles: Array[Dictionary] = []


func set_smoke_active(active: bool) -> void:
	smoke_active = active


func burst() -> void:
	for index in 10:
		particles.append({"position": Vector2.ZERO, "velocity": Vector2.from_angle(TAU * index / 10.0) * 55.0, "life": 0.45, "color": Color(0.3, 0.8, 1.0, 0.9)})


func _process(delta: float) -> void:
	if not smoke_active and particles.is_empty():
		return
	spawn_cooldown -= delta
	if smoke_active and spawn_cooldown <= 0.0:
		spawn_cooldown = 0.13
		particles.append({"position": Vector2(0, 28), "velocity": Vector2(randf_range(-8, 8), 35), "life": 0.75, "color": Color(0.12, 0.13, 0.15, 0.65)})
	for particle in particles:
		particle.position += particle.velocity * delta
		particle.life -= delta
	particles = particles.filter(func(particle): return particle.life > 0.0)
	queue_redraw()


func _draw() -> void:
	for particle in particles:
		draw_circle(particle.position, 3.0 + particle.life * 3.0, Color(particle.color, minf(particle.color.a, particle.life * 2.0)))
