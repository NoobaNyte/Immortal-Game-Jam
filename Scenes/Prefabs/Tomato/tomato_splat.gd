extends Node2D

@export_category("Liquid Splat Settings")
@export var droplet_texture: Texture2D
@export var droplet_count: int = 15
@export var spread_angle: float = PI / 1.5
@export var spray_distance_min: float = 20.0
@export var spray_distance_max: float = 60.0

@export_category("Physics Particles")
@export var particle_textures: Array[Texture2D]
@export var physics_particle_count: int = 8
@export var particle_size_min: float = 0.4
@export var particle_size_max: float = 0.9
@export var particle_lifetime: float = 2.0
@export var particle_fade_duration: float = 0.5
@export var particle_min_speed: float = 250.0

@export_category("Particle Colors")
@export var primary_color: Color = Color.RED
@export var primary_color_chance: float = 0.8
@export var secondary_color: Color = Color.GREEN
@export var secondary_color_chance: float = 0.2

@onready var light: PointLight2D = $SplatLight

# ADDED hit_collider argument here (defaults to null so it doesn't break if you don't pass it)
func setup_splat(impact_velocity: Vector2, splat_color: Color, surface_normal: Vector2, contact_point: Vector2, hit_collider: Object = null) -> void:
    global_position = contact_point
    light.color = splat_color
    
    var cast_origin = contact_point + (surface_normal * 15.0)
    var space_state = get_world_2d().direct_space_state
    
    var safe_spawn_points: Array[Dictionary] = []
    
    for i in range(droplet_count):
        var angle = randf_range(-spread_angle / 2.0, spread_angle / 2.0)
        var ray_dir = (-surface_normal).rotated(angle)
        
        # Randomize the spray distance for each droplet
        var current_spray_distance = randf_range(spray_distance_min, spray_distance_max)
        var cast_end = cast_origin + (ray_dir * current_spray_distance)
        
        var query = PhysicsRayQueryParameters2D.create(cast_origin, cast_end)
        query.collision_mask = 1
        
        var result = space_state.intersect_ray(query)
        if result:
            # FIX: Only spawn the droplet if it hit the exact same object the tomato hit!
            # (Or if hit_collider is null, meaning we hit standard level geometry)
            if hit_collider == null or result.collider == hit_collider:
                _spawn_droplet(result.position, result.normal, splat_color)
                safe_spawn_points.append({
                    "pos": result.position,
                    "normal": result.normal
                })
            
    # Pick one random index to guarantee a secondary color
    var guaranteed_secondary_idx = -1
    if physics_particle_count > 0:
        guaranteed_secondary_idx = randi() % physics_particle_count
            
    for i in range(physics_particle_count):
        var spawn_pos = contact_point
        var spawn_normal = surface_normal
        
        if safe_spawn_points.size() > 0:
            var random_spot = safe_spawn_points.pick_random()
            spawn_pos = random_spot["pos"]
            spawn_normal = random_spot["normal"]
            
        var force_secondary = (i == guaranteed_secondary_idx)
        _spawn_physics_particle(impact_velocity, spawn_normal, spawn_pos, force_secondary)

func _spawn_droplet(pos: Vector2, normal: Vector2, color: Color) -> void:
    var droplet = Sprite2D.new()
    droplet.texture = droplet_texture
    droplet.modulate = color
    
    var scale_y = randf_range(0.5, 1.2)
    var scale_x = randf_range(0.8, 1.5)
    droplet.scale = Vector2(scale_x, scale_y)
    
    droplet.rotation = normal.angle() + (PI / 2.0)
    
    add_child(droplet)
    droplet.global_position = pos + (normal * 0.5)

func _spawn_physics_particle(incoming_vel: Vector2, normal: Vector2, safe_pos: Vector2, force_secondary: bool) -> void:
    if particle_textures.is_empty():
        return
    
    var rb = RigidBody2D.new()
    rb.collision_layer = 0
    rb.collision_mask = 1
    
    # FIX: This detaches the rigid body from the moving platform's local coordinates,
    # forcing it to fly and simulate in global world space!
    rb.top_level = true
    
    var mat = PhysicsMaterial.new()
    mat.bounce = 0.4
    mat.friction = 0.6
    rb.physics_material_override = mat
    
    var sprite = Sprite2D.new()
    sprite.texture = particle_textures.pick_random()
    
    var target_color: Color
    if force_secondary:
        target_color = secondary_color
    else:
        var total_chance = primary_color_chance + secondary_color_chance
        var roll = randf_range(0.0, total_chance)
        if roll <= primary_color_chance:
            target_color = primary_color
        else:
            target_color = secondary_color
        
    sprite.modulate = target_color
    sprite.modulate.a = 0.0
    
    var random_scale = randf_range(particle_size_min, particle_size_max)
    var target_scale = Vector2(random_scale, random_scale)
    sprite.scale = Vector2.ZERO
    
    rb.add_child(sprite)
    
    var coll = CollisionShape2D.new()
    var shape = CircleShape2D.new()
    shape.radius = 2.0 * random_scale
    coll.shape = shape
    rb.add_child(coll)
    
    var spread = randf_range(-PI / 3.0, PI / 3.0)
    var shoot_dir = normal.rotated(spread)
    
    var tomato_speed = incoming_vel.length()
    var speed = max(tomato_speed * randf_range(0.3, 0.7), particle_min_speed * randf_range(0.8, 1.2))
    
    rb.linear_velocity = shoot_dir * speed
    rb.angular_velocity = randf_range(-15.0, 15.0)
    
    add_child(rb)
    
    rb.global_position = safe_pos + (normal * 4.0)

    var tween = create_tween()
    
    tween.set_parallel(true)
    tween.tween_property(sprite, "modulate:a", target_color.a, 0.1)
    tween.tween_property(sprite, "scale", target_scale, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    
    tween.set_parallel(false)
    tween.tween_interval(particle_lifetime)
    tween.tween_property(sprite, "modulate:a", 0.0, particle_fade_duration)
    tween.tween_callback(rb.queue_free)