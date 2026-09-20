extends CharacterBody2D

# --- MOVEMENT SETTINGS ---
@export var speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 2500.0

# --- JUMP SETTINGS ---
@export var max_jump_velocity: float = -500.0
@export var min_jump_velocity: float = -200.0
@export var gravity: float = 1200.0
@export var fall_gravity_multiplier: float = 1.5
@export var max_fall_speed: float = 600.0

# --- COYOTE TIME ---
@export var coyote_time: float = 0.15
var coyote_timer: float = 0.0

# --- BAT MODE SETTINGS ---
var is_bat_mode: bool = false
@export var bat_flap_velocity: float = -350.0
@export var bat_fall_speed: float = 200.0

# --- THROW / PICKUP SETTINGS ---
var held_item: Node2D = null
var is_item_busy: bool = false
@export var throw_speed: float = 600.0
@export var drop_velocity: float = -100.0

# --- KNOCKBACK SETTINGS ---
@export var knockback_recovery_time: float = 0.3
@export var knockback_invuln_time: float = 0.5
var is_knocked_back: bool = false
var knockback_timer: float = 0.0
var knockback_invuln_timer: float = 0.0

# --- DEATH SETTINGS ---
@export_category("Death Settings")
@export var death_hang_time: float = 2.0
@export var respawn_flash_count: int = 4
var is_dying: bool = false
var death_spin_velocity: float = 0.0 # Add this line

# --- HOLD POINT BOB & SWAY SETTINGS ---
@export_category("Hold Point Bob & Sway")
@export var bob_run_speed: float = 15.0
@export var bob_run_amount: float = 3.0
@export var bob_idle_speed: float = 3.0
@export var bob_idle_amount: float = 1.0
@export var bob_air_speed: float = 6.0
@export var bob_air_amount: float = 2.0

@export var sway_run_amount: float = 0.2
@export var sway_idle_amount: float = 0.05
@export var sway_air_amount: float = 0.1

# --- HOLD POINT OFFSETS ---
@export_category("Hold Point Offsets")
@export var offset_idle_right: Vector2 = Vector2(8, 0)
@export var offset_idle_left: Vector2 = Vector2(-8, 0)
@export var offset_run_right: Vector2 = Vector2(8, 0)
@export var offset_run_left: Vector2 = Vector2(-8, 0)
@export var offset_jump_right: Vector2 = Vector2(8, 0)
@export var offset_jump_left: Vector2 = Vector2(-8, 0)

var bob_time: float = 0.0
var base_hold_pos: Vector2 = Vector2.ZERO

# --- AUDIO SETTINGS ---
@export_category("Audio Settings")
@export var player_footsteps_node_parent: Node
@export var footstep_pitch_min: float = 0.8
@export var footstep_pitch_max: float = 1.2
@export var footstep_interval: float = 0.3
var footstep_timer: float = 0.0

@export var bat_flap_sfx: AudioStreamPlayer
@export var bat_flap_pitch_min: float = 0.9
@export var bat_flap_pitch_max: float = 1.1

@export var bat_hurt_sfx: AudioStreamPlayer
@export var bat_hurt_pitch_min: float = 0.9
@export var bat_hurt_pitch_max: float = 1.1

# --- CAMERA LOOK SETTINGS ---
@export var camera_look_offset: float = 120.0
@export var camera_look_delay: float = 0.6
@export var camera_pan_speed: float = 6.0
var look_timer: float = 0.0
var target_camera_y: float = 0.0

# --- ANIMATION STATE ---
var is_action_anim_playing: bool = false
var was_on_floor: bool = true

# --- NODES ---
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var pickup_area: Area2D = $PickupArea

## collision shapes
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var player_collision_shape: CapsuleShape2D
@export var bat_collision_shape: CapsuleShape2D

## player light
@onready var player_point_light: PointLight2D = $PlayerPointLight2D
@onready var original_player_point_light_energy: float = player_point_light.energy

## hold point & camera
@onready var tomato_hold_point: Marker2D = $TomatoHoldPoint
@onready var camera: Camera2D = $Camera2D

@export var player_respawn_point: Marker2D

## for end scene
## set by the end game area script
var disable_input: bool = false
var disable_anim_player: bool = false
var disable_sfx: bool = false

func _ready():
	anim_sprite.play("PlayerIdle")
	anim_sprite.animation_finished.connect(_on_animation_finished)
	
	base_hold_pos = tomato_hold_point.position
	
	if tomato_hold_point.get_child_count() > 0:
		tomato_hold_point.get_child(0).queue_free()

func _physics_process(delta: float) -> void:
	# Custom physics for the death tumbling effect
	if is_dying:
		velocity.y += gravity * delta
		anim_sprite.rotation += death_spin_velocity * delta
		
		# move_and_collide gives us true physics bouncing without normal sliding rules
		var collision = move_and_collide(velocity * delta)
		if collision:
			# Bounce off the surface and lose some momentum
			velocity = velocity.bounce(collision.get_normal()) * 0.6
			# Add friction to slow down the spin when hitting the ground
			death_spin_velocity *= 0.7
		return

	was_on_floor = is_on_floor()
	
	if knockback_invuln_timer > 0.0:
		knockback_invuln_timer -= delta
	
	handle_gravity(delta)
	handle_jump(delta)
	
	if is_knocked_back:
		knockback_timer -= delta
		if knockback_timer <= 0.0:
			is_knocked_back = false
	else:
		handle_movement(delta)
	
	handle_camera_look(delta)
	handle_item_bob_and_sway(delta)
	handle_footsteps(delta)
	
	move_and_slide()
	
	handle_hazard_collisions()
	
	if not was_on_floor and is_on_floor() and not is_bat_mode:
		if not disable_anim_player:
			play_action_anim("PlayerLand")
		play_footstep()
		
	update_animations()

func apply_knockback(knock_vector: Vector2) -> void:
	if knockback_invuln_timer > 0.0 or is_dying:
		return
	
	velocity = knock_vector
	is_knocked_back = true
	knockback_timer = knockback_recovery_time
	knockback_invuln_timer = knockback_invuln_time

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		var current_gravity = gravity
		
		if velocity.y > 0 and not is_bat_mode:
			current_gravity *= fall_gravity_multiplier
			
		velocity.y += current_gravity * delta
		
		var terminal_velocity = bat_fall_speed if is_bat_mode else max_fall_speed
		if velocity.y > terminal_velocity:
			velocity.y = terminal_velocity

func handle_jump(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	if disable_input:
		return

	if Input.is_action_just_released("jump") and velocity.y < min_jump_velocity and not is_bat_mode:
		velocity.y = min_jump_velocity

	if Input.is_action_just_pressed("jump"):
		if is_bat_mode:
			velocity.y = bat_flap_velocity
			play_bat_flap_sfx()
		elif coyote_timer > 0.0:
			velocity.y = max_jump_velocity
			coyote_timer = 0.0

func handle_movement(delta: float) -> void:
	var direction := 0.0
	
	# Only read input if it is not disabled
	if not disable_input:
		direction = Input.get_axis("move_left", "move_right")
	
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		if not is_action_anim_playing or anim_sprite.animation == "PlayerLand":
			anim_sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func handle_item_bob_and_sway(delta: float) -> void:
	if is_bat_mode:
		return
		
	var target_bob = 0.0
	var target_sway = 0.0
	var target_speed = 0.0
	var target_offset = Vector2.ZERO
	var is_facing_left = anim_sprite.flip_h
	
	if not is_on_floor():
		target_bob = bob_air_amount
		target_sway = sway_air_amount
		target_speed = bob_air_speed
		target_offset = offset_jump_left if is_facing_left else offset_jump_right
	elif velocity.x != 0:
		target_bob = bob_run_amount
		target_sway = sway_run_amount
		target_speed = bob_run_speed
		target_offset = offset_run_left if is_facing_left else offset_run_right
	else:
		target_bob = bob_idle_amount
		target_sway = sway_idle_amount
		target_speed = bob_idle_speed
		target_offset = offset_idle_left if is_facing_left else offset_idle_right
			
	bob_time += delta * target_speed
	
	var target_y = base_hold_pos.y + target_offset.y + (sin(bob_time) * target_bob)
	var target_x = base_hold_pos.x + target_offset.x
	var target_rot = cos(bob_time) * target_sway
	
	tomato_hold_point.position.y = lerp(tomato_hold_point.position.y, target_y, 15.0 * delta)
	tomato_hold_point.position.x = lerp(tomato_hold_point.position.x, target_x, 15.0 * delta)
	tomato_hold_point.rotation = lerp_angle(tomato_hold_point.rotation, target_rot, 15.0 * delta)

func handle_footsteps(delta: float) -> void:
	if is_on_floor() and velocity.x != 0 and not is_bat_mode:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			play_footstep()
			footstep_timer = footstep_interval
	else:
		footstep_timer = 0.0

func play_footstep() -> void:
	if disable_sfx:
		return


	if not player_footsteps_node_parent:
		return
		
	var count = player_footsteps_node_parent.get_child_count()
	if count == 0:
		return
		
	var random_player = player_footsteps_node_parent.get_child(randi() % count) as AudioStreamPlayer
	if random_player:
		random_player.pitch_scale = randf_range(footstep_pitch_min, footstep_pitch_max)
		random_player.play()

func play_bat_flap_sfx() -> void:
	if bat_flap_sfx:
		bat_flap_sfx.pitch_scale = randf_range(bat_flap_pitch_min, bat_flap_pitch_max)
		bat_flap_sfx.play()

func play_bat_hurt_sfx() -> void:
	if bat_hurt_sfx:
		bat_hurt_sfx.pitch_scale = randf_range(bat_hurt_pitch_min, bat_hurt_pitch_max)
		bat_hurt_sfx.play()

func handle_camera_look(delta: float) -> void:
	# Add 'and not disable_input' to prevent camera panning
	if is_on_floor() and velocity.x == 0 and not is_bat_mode and not disable_input:
		var look_dir = Input.get_axis("look_up", "look_down")
		
		if look_dir != 0:
			look_timer += delta
			if look_timer >= camera_look_delay:
				target_camera_y = look_dir * camera_look_offset
		else:
			look_timer = 0.0
			target_camera_y = 0.0
	else:
		look_timer = 0.0
		target_camera_y = 0.0

	camera.position.y = lerp(camera.position.y, target_camera_y, camera_pan_speed * delta)

func handle_hazard_collisions() -> void:
	if not is_bat_mode:
		return
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider is TileMapLayer or collider is TileMap:
			var contact_point = collision.get_position() - (collision.get_normal() * 2.0)
			var local_pos = collider.to_local(contact_point)
			var map_pos = collider.local_to_map(local_pos)
			
			var tile_data: TileData = null
			var tile_set: TileSet = collider.tile_set
			
			if not tile_set or tile_set.get_custom_data_layer_by_name("HurtsPlayer") == -1:
				continue
			
			if collider is TileMapLayer:
				tile_data = collider.get_cell_tile_data(map_pos)
			elif collider is TileMap:
				for layer in collider.get_layers_count():
					tile_data = collider.get_cell_tile_data(layer, map_pos)
					if tile_data: break
			
			if tile_data and tile_data.get_custom_data("HurtsPlayer") == true:
				# Pass the exact wall/ceiling/floor normal into the die function
				die(collision.get_normal())
				break

func die(hit_normal: Vector2 = Vector2.UP) -> void:
	if is_dying:
		return
		
	is_dying = true
	
	if is_bat_mode:
		play_bat_hurt_sfx()
		
	# Calculate a strong physical pop away from the wall/floor, plus some vertical lift
	var bounce_dir = hit_normal
	if bounce_dir == Vector2.ZERO:
		bounce_dir = Vector2.UP
		
	velocity = (bounce_dir * 50.0) + Vector2(randf_range(-150.0, 150.0), -350.0)
	
	# Give it a fast random spin (clockwise or counter-clockwise)
	death_spin_velocity = randf_range(5.0, 7.0)
	if randf() > 0.5:
		death_spin_velocity *= -1.0
		
	# Just wait out the death hang time, the physics process handles the bouncing
	var tween = create_tween()
	tween.tween_interval(death_hang_time)
	tween.tween_callback(_respawn_sequence)

func _respawn_sequence() -> void:
	if player_respawn_point:
		global_position = player_respawn_point.global_position

	# Reset visual rotation and kill leftover bounce momentum
	anim_sprite.rotation = 0.0
	velocity = Vector2.ZERO
	
	if is_bat_mode:
		toggle_bat_mode()
	
	is_dying = false
	
	var flash_tween = create_tween()
	for i in range(respawn_flash_count):
		flash_tween.tween_property(anim_sprite, "modulate:a", 0.5, 0.1)
		flash_tween.tween_property(anim_sprite, "modulate:a", 1.0, 0.1)

func play_action_anim(anim_name: String) -> void:
	if disable_anim_player:
		return
		
	is_action_anim_playing = true
	anim_sprite.play(anim_name)

func _on_animation_finished() -> void:
	if anim_sprite.animation in ["PlayerLand", "PlayerThrowSide", "PlayerThrowUp"]:
		is_action_anim_playing = false

func update_animations() -> void:
	if disable_anim_player:
		return
		
	if is_action_anim_playing:
		if anim_sprite.animation == "PlayerLand" and (velocity.x != 0 or not is_on_floor()):
			is_action_anim_playing = false
		else:
			return
			
	if is_bat_mode:
		if is_on_floor():
			anim_sprite.play("BatIdle")
		elif velocity.y < 0:
			anim_sprite.play("BatFlap")
		else:
			anim_sprite.play("BatFall")
	else:
		if not is_on_floor():
			if velocity.y < 0:
				anim_sprite.play("PlayerJump")
			else:
				anim_sprite.play("PlayerFall")
		elif velocity.x != 0:
			anim_sprite.play("PlayerRun")
		else:
			anim_sprite.play("PlayerIdle")

func _input(event: InputEvent) -> void:
	# Lock out player inputs if dying OR if input is disabled
	if is_dying or disable_input:
		return
		
	if event.is_action_pressed("toggle_bat_mode"):
		toggle_bat_mode()
		
	if event.is_action_pressed("throw"):
		if held_item:
			throw_item()
		else:
			try_pickup()

func toggle_bat_mode() -> void:
	is_bat_mode = !is_bat_mode
	is_action_anim_playing = false

	if is_bat_mode:
		anim_sprite.play("BatIdle")
		player_point_light.energy = 0.1
		# Use set_deferred so it safely waits for physics to unlock
		collision_shape.set_deferred("shape", bat_collision_shape)
		velocity.y = bat_flap_velocity / 2.0
		play_bat_flap_sfx()

		if held_item:
			throw_item(true)
	else:
		anim_sprite.play("PlayerIdle")
		player_point_light.energy = original_player_point_light_energy
		# Use set_deferred here as well
		collision_shape.set_deferred("shape", player_collision_shape)

func try_pickup() -> void:
	if is_bat_mode or not pickup_area or held_item or is_item_busy: return
	
	var bodies = pickup_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("Grabbable"):
			held_item = body
			is_item_busy = true

			if body.is_in_group("Tomato"):
				body.play_pick_up_tomato_sfx()
			
			if held_item is RigidBody2D:
				held_item.freeze = true
			
			var start_global = held_item.global_position
			held_item.get_parent().remove_child(held_item)
			tomato_hold_point.add_child(held_item)
			held_item.global_position = start_global
			
			var tween = create_tween()
			tween.tween_property(held_item, "position", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_callback(func(): is_item_busy = false)
			break

func throw_item(dropped: bool = false) -> void:
	if not held_item or is_item_busy: return
	
	is_item_busy = true
	var item_to_throw = held_item
	held_item = null

	if "being_thrown" in item_to_throw:
		item_to_throw.being_thrown = true
	
	var throw_start_pos = item_to_throw.global_position
	item_to_throw.get_parent().remove_child(item_to_throw)
	get_tree().current_scene.add_child(item_to_throw)
	item_to_throw.global_position = throw_start_pos
	
	if item_to_throw is RigidBody2D:
		item_to_throw.freeze = false
		
		if dropped:
			item_to_throw.linear_velocity = Vector2(0, drop_velocity)
		else:
			var throw_dir = Input.get_vector("move_left", "move_right", "look_up", "look_down")
			
			if throw_dir == Vector2.ZERO:
				var dir_x = -1 if anim_sprite.flip_h else 1
				throw_dir = Vector2(dir_x, -0.5).normalized()
			else:
				throw_dir = throw_dir.normalized()
			
			item_to_throw.linear_velocity = throw_dir * throw_speed
			
			if throw_dir.y < -0.5 and abs(throw_dir.x) < 0.5:
				play_action_anim("PlayerThrowUp")
			else:
				play_action_anim("PlayerThrowSide")

	is_item_busy = false

func _on_pickup_area_area_entered(area: Area2D) -> void:
	if area.name == "TomatoGrabArea":
		try_pickup()