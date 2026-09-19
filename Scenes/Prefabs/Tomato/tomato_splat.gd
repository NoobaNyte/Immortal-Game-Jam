extends Node2D

@export_category("Liquid Splat Settings")
@export var droplet_texture: Texture2D # Assign your small circle/blob texture here
@export var droplet_count: int = 15 # How many blobs make up one splat
@export var spread_angle: float = PI / 1.5 # How wide the juice spreads (120 degrees)
@export var spray_distance: float = 40.0 # Max distance the splat can wrap

@onready var particles: CPUParticles2D = $SplatParticles
@onready var light: PointLight2D = $SplatLight

func setup_splat(impact_velocity: Vector2, splat_color: Color, surface_normal: Vector2, contact_point: Vector2) -> void:
	global_position = contact_point
	light.color = splat_color
	
	# Pull the raycast origin slightly off the wall so rays have room to travel inward
	var cast_origin = contact_point + (surface_normal * 15.0)
	var space_state = get_world_2d().direct_space_state
	
	for i in range(droplet_count):
		# Generate a random angle within our spread cone
		var angle = randf_range(-spread_angle / 2.0, spread_angle / 2.0)
		
		# Invert the normal (to point at the wall) and rotate it by our random angle
		var ray_dir = (-surface_normal).rotated(angle)
		var cast_end = cast_origin + (ray_dir * spray_distance)
		
		# Create the raycast query (Mask 1 assumes your TileMapLayer is on Layer 1)
		var query = PhysicsRayQueryParameters2D.create(cast_origin, cast_end)
		query.collision_mask = 1
		
		var result = space_state.intersect_ray(query)
		
		# If the ray hits geometry, spawn a droplet at that exact contour
		if result:
			_spawn_droplet(result.position, result.normal, splat_color)
			
	# Configure and fire the burst particles
	particles.direction = surface_normal
	var speed = impact_velocity.length()
	particles.initial_velocity_min = speed * 0.1
	particles.initial_velocity_max = speed * 0.3
	particles.emitting = true

func _spawn_droplet(pos: Vector2, normal: Vector2, color: Color) -> void:
	var droplet = Sprite2D.new()
	droplet.texture = droplet_texture
	droplet.modulate = color
	
	# Randomize scale for organic look
	var scale_y = randf_range(0.5, 1.2)
	var scale_x = randf_range(0.8, 1.5)
	droplet.scale = Vector2(scale_x, scale_y)
	
	# Align rotation to the TileMap wall normal
	droplet.rotation = normal.angle() + (PI / 2.0)
	
	# Add to scene tree FIRST
	add_child(droplet)
	
	# THEN set global position (pushed slightly off the wall to prevent clipping)
	droplet.global_position = pos + (normal * 1.0)