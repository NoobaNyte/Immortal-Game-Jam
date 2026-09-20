extends BaseUIElement

@onready var tomato_sprite: Sprite2D = $TomatoSprite

@export var rotation_speed: float = 2.5 ## Speed of the clockwise rotation in radians per second

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Multiplying by delta ensures smooth, frame-rate independent rotation on web and low-end devices
	tomato_sprite.rotation += rotation_speed * delta