extends Node2D

@onready var particles: CPUParticles2D = $SplatParticles
@onready var sprite: Sprite2D = $SplatSprite
@onready var light: PointLight2D = $SplatLight

func setup_splat(impact_velocity: Vector2, splat_color: Color, surface_normal: Vector2) -> void:
	# 1. Apply the tomato's color
	sprite.modulate = splat_color
	light.color = splat_color
	
	# 2. Align the sprite flush against the wall/floor using the surface normal
	rotation = surface_normal.angle() + (PI / 2.0)
	
	# Push it exactly 1 pixel away from the wall so it doesn't clip into the tile
	global_position += surface_normal * 1.0
	
	# 3. Shoot particles outward away from the wall
	particles.direction = surface_normal
	
	# Scale particle speed based on how hard the tomato hit
	var impact_speed = impact_velocity.length()
	particles.initial_velocity_min = impact_speed * 0.2
	particles.initial_velocity_max = impact_speed * 0.5
	
	# Fire!
	particles.emitting = true