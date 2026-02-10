class_name Player extends CharacterBody2D

signal bullet_shot(bullet_scene, location)

@export var speed = 300
@export var rate_of_fire = 0.2
@onready var muzzle = $Muzzle 

var bullet_scene = preload("res://bullet.tscn")

var shoot_cd := false 

func _process(delta):
	if Input.is_action_pressed("shoot"):
		if !shoot_cd: 
			shoot_cd = true 
			shoot()
			await get_tree().create_timer(rate_of_fire).timeout
			shoot_cd = false 

func _physics_process(delta):
		var direction = Vector2(Input.get_axis("move_left", "move_right"), 
	Input.get_axis("move_up", "move_down"))
		print(direction)
		velocity = direction * speed
		move_and_slide()

func shoot():
	bullet_shot.emit(bullet_scene, muzzle.global_position )
	
func die():
	queue_free()
