@tool
extends Node2D

enum Mode {
	AUTO_PINGPONG,   ## Current behavior: continuously ping-pongs back and forth.
	WAIT_FOR_PLAYER, ## Sits at 0 until the player stands on it, then travels to the end; returns to 0 once they step off.
}

@export var mode: Mode = Mode.AUTO_PINGPONG

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

## Only needed when Mode is Wait For Player. An Area2D placed on top of the
## platform's surface, used to detect when the player is standing on it.
@export var player_detector: Area2D:
	set(value):
		if player_detector and player_detector.body_entered.is_connected(_on_player_detector_body_entered):
			player_detector.body_entered.disconnect(_on_player_detector_body_entered)
			player_detector.body_exited.disconnect(_on_player_detector_body_exited)
		player_detector = value
		if player_detector and not Engine.is_editor_hint():
			player_detector.body_entered.connect(_on_player_detector_body_entered)
			player_detector.body_exited.connect(_on_player_detector_body_exited)

@export var speed: float = 0.2 ## Controls how fast the platform moves along the path.

var _time_passed: float = 0.0
var _wait_progress: float = 0.0   # 0-1 linear progress used in WAIT_FOR_PLAYER mode
var _players_on_platform: int = 0 # supports co-op / multiple overlapping bodies safely


func _ready() -> void:
	apply_platform_transforms()

	if player_detector and not Engine.is_editor_hint():
		if not player_detector.body_entered.is_connected(_on_player_detector_body_entered):
			player_detector.body_entered.connect(_on_player_detector_body_entered)
			player_detector.body_exited.connect(_on_player_detector_body_exited)


func _process(delta: float) -> void:
	if not moving_platform_path_follow:
		return

	match mode:
		Mode.AUTO_PINGPONG:
			_time_passed += delta * speed

			var ping_pong_val = wrapf(_time_passed, 0.0, 2.0)
			if ping_pong_val > 1.0:
				ping_pong_val = 2.0 - ping_pong_val

			var eased_progress = smoothstep(0.0, 1.0, ping_pong_val)
			moving_platform_path_follow.progress_ratio = eased_progress

		Mode.WAIT_FOR_PLAYER:
			var target: float = 1.0 if _players_on_platform > 0 else 0.0
			_wait_progress = move_toward(_wait_progress, target, delta * speed)

			var eased_progress = smoothstep(0.0, 1.0, _wait_progress)
			moving_platform_path_follow.progress_ratio = eased_progress


func _on_player_detector_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_players_on_platform += 1


func _on_player_detector_body_exited(body: Node2D) -> void:
	if _is_player(body):
		_players_on_platform = max(0, _players_on_platform - 1)


func _is_player(body: Node2D) -> bool:
	# Matches the same duck-typing convention used by the minecart/wire scripts -
	# checks for a method unique to the player rather than requiring a group.
	return body.has_method("apply_knockback")


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
