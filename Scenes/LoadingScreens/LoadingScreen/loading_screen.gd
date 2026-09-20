extends BaseUIElement

@onready var tomato_sprite: Sprite2D = $TomatoSprite

@export var rotation_speed: float = 2.5 ## Speed of the clockwise rotation in radians per second

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Multiplying by delta ensures smooth, frame-rate independent rotation on web and low-end devices
	tomato_sprite.rotation += rotation_speed * delta