@tool
extends Node2D

@export var moving_platform_texture: CompressedTexture2D:
	set(value):
		moving_platform_texture = value
		set_moving_platform_sprite()

@export var moving_platform_sprite: Sprite2D
@export var moving_platform_path_follow: PathFollow2D

@export var speed: float = 0.2 ## Controls how fast the platform moves along the path.

var _time_passed: float = 0.0

func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	# Skip path logic if in the editor and path isn't assigned yet
	if not moving_platform_path_follow:
		return
		
	# Accumulate time
	_time_passed += delta * speed
	
	# 1. Ping-pong the time between 0.0 and 1.0 using a triangle wave / pingpong function
	var ping_pong_val = wrapf(_time_passed, 0.0, 2.0)
	if ping_pong_val > 1.0:
		ping_pong_val = 2.0 - ping_pong_val
		
	# 2. Apply ease-in-out curve (smoothstep provides a clean smooth ease at both ends)
	var eased_progress = smoothstep(0.0, 1.0, ping_pong_val)
	
	# 3. Apply to the PathFollow2D progress ratio (ranges from 0.0 to 1.0)
	moving_platform_path_follow.progress_ratio = eased_progress

func set_moving_platform_sprite():
	if moving_platform_sprite:
		moving_platform_sprite.texture = moving_platform_texture
