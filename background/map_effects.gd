extends Node2D

const VIEWPORT_SIZE := Vector2(540, 960)

var effect_type := "ocean"
var particles: Array[Dictionary] = []
var elapsed := 0.0
var lightning_countdown := 12.0
var lightning_alpha := 0.0
var update_accumulator := 0.0
const EFFECT_UPDATE_INTERVAL := 1.0 / 30.0


func _ready() -> void:
	set_effect(effect_type)


func set_effect(map_id: String) -> void:
	effect_type = map_id
	particles.clear()
	elapsed = 0.0
	lightning_countdown = randf_range(10.0, 18.0)
	lightning_alpha = 0.0
	update_accumulator = 0.0

	var particle_count := 0
	if effect_type == "desert":
		particle_count = 34
	elif effect_type == "grassland":
		particle_count = 5

	for index in particle_count:
		particles.append(_create_particle(index))

	queue_redraw()


func _process(delta: float) -> void:
	update_accumulator += delta
	if update_accumulator < EFFECT_UPDATE_INTERVAL:
		return

	var update_delta := update_accumulator
	update_accumulator = 0.0
	elapsed += update_delta

	for index in particles.size():
		var particle := particles[index]
		particle.position += particle.velocity * update_delta

		if particle.position.y > VIEWPORT_SIZE.y + 120.0:
			particle.position.y = -120.0
			particle.position.x = randf_range(-80.0, VIEWPORT_SIZE.x + 80.0)

		if particle.position.x > VIEWPORT_SIZE.x + 120.0:
			particle.position.x = -120.0

		particles[index] = particle

	if effect_type == "ocean":
		lightning_countdown -= update_delta
		if lightning_countdown <= 0.0:
			lightning_alpha = 0.24
			lightning_countdown = randf_range(12.0, 22.0)

	lightning_alpha = maxf(0.0, lightning_alpha - update_delta * 1.8)
	queue_redraw()


func _draw() -> void:
	match effect_type:
		"grassland":
			_draw_fog()
		"desert":
			_draw_sandstorm()
		_:
			_draw_clouds()


func _draw_clouds() -> void:
	for particle in particles:
		var position: Vector2 = particle.position
		var size: float = particle.size
		var color := Color(0.9, 0.96, 1.0, particle.alpha)
		draw_circle(position, size, color)
		draw_circle(position + Vector2(size * 0.7, 4), size * 0.72, color)
		draw_circle(position - Vector2(size * 0.65, -5), size * 0.6, color)

	if lightning_alpha > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEWPORT_SIZE), Color(0.75, 0.9, 1.0, lightning_alpha))


func _draw_fog() -> void:
	for particle in particles:
		var position: Vector2 = particle.position
		var fog_rect := Rect2(-100.0, position.y, 740.0, particle.size)
		draw_rect(fog_rect, Color(0.86, 0.92, 0.82, particle.alpha))


func _draw_sandstorm() -> void:
	for particle in particles:
		var position: Vector2 = particle.position
		var end_position := position + Vector2(34.0, 15.0)
		draw_line(
			position,
			end_position,
			Color(1.0, 0.72, 0.28, particle.alpha),
			particle.size
		)

	draw_rect(Rect2(Vector2.ZERO, VIEWPORT_SIZE), Color(0.72, 0.38, 0.08, 0.035))


func _create_particle(index: int) -> Dictionary:
	var particle := {
		"position": Vector2(
			randf_range(-80.0, VIEWPORT_SIZE.x + 80.0),
			randf_range(-100.0, VIEWPORT_SIZE.y)
		),
		"velocity": Vector2(8.0, 22.0),
		"size": 35.0,
		"alpha": 0.055
	}

	match effect_type:
		"grassland":
			particle.velocity = Vector2(0.0, randf_range(8.0, 14.0))
			particle.size = randf_range(65.0, 120.0)
			particle.alpha = randf_range(0.025, 0.055)
		"desert":
			particle.velocity = Vector2(randf_range(55.0, 95.0), randf_range(35.0, 60.0))
			particle.size = randf_range(1.0, 2.5)
			particle.alpha = randf_range(0.16, 0.34)
		_:
			particle.velocity = Vector2(randf_range(-5.0, 7.0), randf_range(14.0, 24.0))
			particle.size = randf_range(25.0, 55.0)
			particle.alpha = randf_range(0.025, 0.065)

	particle.position.x += index * 11.0
	return particle
