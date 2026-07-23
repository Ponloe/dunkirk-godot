extends Control

const HEART_TEXTURE: Texture2D = preload("res://assets/heart-removebg-preview.png")
const POWER_UP_TEXTURES := {
	PowerUp.RAPID_FIRE: preload("res://assets/rapid_fire-removebg-preview.png"),
	PowerUp.SPREAD_SHOT: preload("res://assets/spread_shot.png"),
	PowerUp.SHIELD: preload("res://assets/shield.png"),
	PowerUp.TWIN_CANNONS: preload("res://assets/twin_cannons.png"),
	PowerUp.BOMB: preload("res://assets/bomb.png")
}
const POWER_UP_NAMES := {
	PowerUp.RAPID_FIRE: "RAPID FIRE",
	PowerUp.SPREAD_SHOT: "SPREAD SHOT",
	PowerUp.SHIELD: "SHIELD",
	PowerUp.TWIN_CANNONS: "TWIN CANNONS",
	PowerUp.BOMB: "BOMB"
}

@onready var score_label: Label = $Score
@onready var kill_counter_label: Label = $KillCounter
@onready var combo_label: Label = $Combo
@onready var lives_container: HBoxContainer = $Lives/LivesContainer
@onready var active_power_ups: VBoxContainer = $ActivePowerUps
@onready var boss_warning: Label = $BossWarning
@onready var boss_warning_shade: ColorRect = $BossWarningShade
@onready var level_intro: Label = $LevelIntro
@onready var level_intro_shade: ColorRect = $LevelIntroShade
@onready var boss_health_panel: Panel = $BossHealth
@onready var boss_health_bar: ProgressBar = $BossHealth/HealthBar
@onready var boss_health_text: Label = $BossHealth/HealthText
@onready var tip_panel: Panel = $TipPanel
@onready var tip_label: Label = $TipPanel/Tip
@onready var endless_ribbon: Panel = $EndlessRibbon

var power_up_statuses: Dictionary = {}
var warning_tween: Tween
var tip_tween: Tween
var endless_ribbon_tween: Tween

var score := 0:
	set(value):
		score = value
		if is_instance_valid(score_label):
			score_label.text = "SCORE: " + GameData.format_number(value)


func _ready() -> void:
	score_label.text = "SCORE: " + GameData.format_number(score)
	boss_warning.visible = false
	boss_warning_shade.visible = false
	level_intro.visible = false
	level_intro_shade.visible = false
	boss_health_panel.visible = false
	tip_panel.visible = false
	endless_ribbon.visible = false
	combo_label.visible = false


func _process(delta: float) -> void:
	if get_tree().paused:
		return

	for power_up_type in power_up_statuses.keys():
		var status: Dictionary = power_up_statuses[power_up_type]
		var remaining: float = status.remaining

		if remaining < 0.0:
			continue

		remaining = maxf(0.0, remaining - delta)
		status.remaining = remaining
		status.label.text = "%s  %.1fs" % [
			POWER_UP_NAMES.get(power_up_type, power_up_type.to_upper()),
			remaining
		]
		power_up_statuses[power_up_type] = status

		if remaining <= 0.0:
			hide_power_up(power_up_type)


func set_lives(current_lives: int, max_lives: int) -> void:
	for child in lives_container.get_children():
		child.free()

	for life_index in max_lives:
		var heart := TextureRect.new()
		heart.custom_minimum_size = Vector2(24, 24)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.texture = HEART_TEXTURE
		heart.modulate = Color.WHITE if life_index < current_lives else Color(0.25, 0.25, 0.25, 0.55)
		lives_container.add_child(heart)


func set_kill_progress(kills: int, guaranteed_drop_interval: int) -> void:
	if guaranteed_drop_interval <= 0:
		kill_counter_label.text = "SUPPLY: RANDOM"
		return

	var progress := kills % guaranteed_drop_interval
	kill_counter_label.text = "SUPPLY: %d/%d" % [progress, guaranteed_drop_interval]


func set_combo(combo_count: int, multiplier: float) -> void:
	combo_label.visible = combo_count >= 2
	combo_label.text = "COMBO %d  x%.2f" % [combo_count, multiplier]


func show_tip(message: String, duration := 3.5) -> void:
	if tip_tween != null:
		tip_tween.kill()

	tip_label.text = message
	tip_panel.visible = true
	tip_panel.modulate.a = 0.0
	tip_tween = create_tween()
	tip_tween.tween_property(tip_panel, "modulate:a", 1.0, 0.2)
	tip_tween.tween_interval(duration)
	tip_tween.tween_property(tip_panel, "modulate:a", 0.0, 0.35)
	tip_tween.tween_callback(func(): tip_panel.visible = false)


func show_endless_ribbon() -> void:
	if endless_ribbon_tween != null:
		endless_ribbon_tween.kill()

	endless_ribbon.visible = true
	endless_ribbon.position = Vector2(155.0, 64.0)
	endless_ribbon.modulate.a = 0.0
	endless_ribbon_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	endless_ribbon_tween.set_parallel(true)
	endless_ribbon_tween.tween_property(endless_ribbon, "position:y", 78.0, 0.22)
	endless_ribbon_tween.tween_property(endless_ribbon, "modulate:a", 1.0, 0.18)
	endless_ribbon_tween.set_parallel(false)
	endless_ribbon_tween.tween_interval(1.45)
	endless_ribbon_tween.set_parallel(true)
	endless_ribbon_tween.tween_property(endless_ribbon, "position:y", 68.0, 0.24).set_ease(Tween.EASE_IN)
	endless_ribbon_tween.tween_property(endless_ribbon, "modulate:a", 0.0, 0.2)
	endless_ribbon_tween.set_parallel(false)
	endless_ribbon_tween.tween_callback(func(): endless_ribbon.visible = false)


func show_power_up(power_up_type: String, duration: float) -> void:
	hide_power_up(power_up_type)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = POWER_UP_TEXTURES.get(power_up_type)
	row.add_child(icon)

	var status_label := Label.new()
	status_label.add_theme_font_override("font", preload("res://assets/font/font.ttf"))
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.text = (
		POWER_UP_NAMES.get(power_up_type, power_up_type.to_upper()) + "  1 HIT"
		if duration < 0.0
		else "%s  %.1fs" % [POWER_UP_NAMES.get(power_up_type, power_up_type.to_upper()), duration]
	)
	row.add_child(status_label)
	active_power_ups.add_child(row)

	power_up_statuses[power_up_type] = {
		"remaining": duration,
		"row": row,
		"label": status_label
	}


func hide_power_up(power_up_type: String) -> void:
	if not power_up_statuses.has(power_up_type):
		return

	var status: Dictionary = power_up_statuses[power_up_type]
	status.row.free()
	power_up_statuses.erase(power_up_type)


func clear_power_ups() -> void:
	for power_up_type in power_up_statuses.keys():
		hide_power_up(power_up_type)


func show_boss_warning() -> void:
	boss_warning.visible = true
	boss_warning_shade.visible = true
	boss_warning.modulate.a = 1.0
	if warning_tween != null:
		warning_tween.kill()
	warning_tween = create_tween().set_loops()
	warning_tween.tween_property(boss_warning, "modulate:a", 0.25, 0.28)
	warning_tween.tween_property(boss_warning, "modulate:a", 1.0, 0.28)


func hide_boss_warning() -> void:
	boss_warning.visible = false
	boss_warning_shade.visible = false
	if warning_tween != null:
		warning_tween.kill()
	boss_warning.modulate.a = 1.0


func show_level_intro(title: String) -> void:
	level_intro.text = title
	level_intro.visible = true
	level_intro_shade.visible = true
	level_intro.modulate.a = 0.0
	level_intro.scale = Vector2(0.88, 0.88)
	level_intro.pivot_offset = level_intro.size / 2.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(level_intro, "modulate:a", 1.0, 0.35)
	tween.tween_property(level_intro, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(false)
	tween.tween_interval(1.8)
	tween.tween_property(level_intro, "modulate:a", 0.0, 0.45)
	tween.tween_callback(_hide_level_intro)


func show_secret_plane_unlocked() -> void:
	show_level_intro("CLASSIFIED AIRCRAFT UNLOCKED!\nNIGHT REAPER AVAILABLE")


func _hide_level_intro() -> void:
	level_intro.visible = false
	level_intro_shade.visible = false


func show_boss_health(current_hp: int, max_hp: int) -> void:
	boss_health_panel.visible = true
	boss_health_bar.max_value = max_hp
	boss_health_bar.value = current_hp
	boss_health_text.text = "ACE  %d / %d" % [current_hp, max_hp]


func hide_boss_health() -> void:
	boss_health_panel.visible = false
