extends ParallaxBackground

@export var scroll_speed = 100.0

func _process(delta):
	# Scroll down continuously
	scroll_offset.y += scroll_speed * delta
