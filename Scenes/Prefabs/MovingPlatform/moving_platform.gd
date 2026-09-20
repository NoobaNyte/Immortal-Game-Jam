@tool
extends Node2D

@export var moving_platform_texture: CompressedTexture2D:
	set(value):
		moving_platform_texture = value
		set_moving_platform_sprite()

@export var platform_scale: Vector2 = Vector2.ONE:
	set(value):
		platform_scale = value
		apply_platform_transforms()

@export var platform_offset: Vector2 = Vector2.ZERO:
	set(value):
		platform_offset = value
		apply_platform_transforms()

@export var animatable_body: AnimatableBody2D
@export var moving_platform_sprite: Sprite2D
@export var moving_platform_collision_polygon: CollisionPolygon2D
@export var moving_platform_path_follow: PathFollow2D

@export var speed: float = 0.2 ## Controls how fast the platform moves along the path.

var _time_passed: float = 0.0

func _ready() -> void:
	apply_platform_transforms()

func _process(delta: float) -> void:
	if not moving_platform_path_follow:
		return
		
	_time_passed += delta * speed
	
	var ping_pong_val = wrapf(_time_passed, 0.0, 2.0)
	if ping_pong_val > 1.0:
		ping_pong_val = 2.0 - ping_pong_val
		
	var eased_progress = smoothstep(0.0, 1.0, ping_pong_val)
	moving_platform_path_follow.progress_ratio = eased_progress

func set_moving_platform_sprite():
	# 1. Update the Sprite2D texture
	if moving_platform_sprite:
		moving_platform_sprite.texture = moving_platform_texture
		
	# 2. Automatically generate a precise outline polygon using the texture's alpha channel
	if moving_platform_collision_polygon and moving_platform_texture:
		var image = moving_platform_texture.get_image()
		if image:
			var bitmap = BitMap.new()
			bitmap.create_from_image_alpha(image)
			
			var rect = Rect2(Vector2.ZERO, image.get_size())
			var polygons = bitmap.opaque_to_polygons(rect, 2.0)
			
			if not polygons.is_empty():
				var poly = polygons[0]
				
				if moving_platform_sprite and moving_platform_sprite.centered:
					var offset = image.get_size() / 2.0
					for i in range(poly.size()):
						poly[i] -= offset
						
				moving_platform_collision_polygon.polygon = poly
				
	apply_platform_transforms()

func apply_platform_transforms():
	# Apply offset to the AnimatableBody2D
	if animatable_body:
		animatable_body.position = platform_offset
		
	# Apply scale to the sprite and collision polygon
	if moving_platform_sprite:
		moving_platform_sprite.scale = platform_scale
	if moving_platform_collision_polygon:
		moving_platform_collision_polygon.scale = platform_scale
