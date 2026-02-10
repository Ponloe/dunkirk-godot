extends ParallaxBackground

# Control how fast the sky moves. 
# Positive moves down (simulating player flying up)
@export var scroll_speed = 100.0

func _process(delta):
	# This automatically scrolls the background offset
	scroll_offset.y += scroll_speed * delta
