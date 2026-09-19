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
var is_item_busy: bool = false # Prevents spamming pickup/throw buttons
@export var throw_speed: float = 600.0 # Replaces the hardcoded vector for omnidirectional throws
@export var drop_velocity: float = -100.0 # A gentle upwards toss for a nice drop

# --- CAMERA LOOK SETTINGS ---
@export var camera_look_offset: float = 120.0
@export var camera_look_delay: float = 0.6
@export var camera_pan_speed: float = 6.0
var look_timer: float = 0.0
var target_camera_y: float = 0.0

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

func _ready():
	anim_sprite.play("PlayerIdle")
	
	if tomato_hold_point.get_child_count() > 0:
		tomato_hold_point.get_child(0).queue_free()

func _physics_process(delta: float) -> void:
	handle_gravity(delta)
	handle_jump(delta)
	handle_movement(delta)
	handle_camera_look(delta)
	
	move_and_slide()
	update_animations()

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

	if Input.is_action_just_released("jump") and velocity.y < min_jump_velocity and not is_bat_mode:
		velocity.y = min_jump_velocity

	if Input.is_action_just_pressed("jump"):
		if is_bat_mode:
			velocity.y = bat_flap_velocity
		elif coyote_timer > 0.0:
			velocity.y = max_jump_velocity
			coyote_timer = 0.0

func handle_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		anim_sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func handle_camera_look(delta: float) -> void:
	# Only allow camera panning if standing entirely still on the ground
	if is_on_floor() and velocity.x == 0 and not is_bat_mode:
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

	# Smoothly interpolate the camera's position
	camera.position.y = lerp(camera.position.y, target_camera_y, camera_pan_speed * delta)

func update_animations() -> void:
	if is_bat_mode:
		if velocity.y < 0:
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
	if event.is_action_pressed("toggle_bat_mode"):
		toggle_bat_mode()
		
	if event.is_action_pressed("throw"):
		if held_item:
			throw_item()
		else:
			try_pickup()

func toggle_bat_mode() -> void:
	is_bat_mode = !is_bat_mode

	if is_bat_mode:
		anim_sprite.play("BatIdle")
		player_point_light.energy = 0.1
		collision_shape.shape = bat_collision_shape
		velocity.y = bat_flap_velocity / 2.0

		if held_item:
			throw_item(true)
	else:
		anim_sprite.play("PlayerIdle")
		player_point_light.energy = original_player_point_light_energy
		collision_shape.shape = player_collision_shape

func try_pickup() -> void:
	if is_bat_mode or not pickup_area or held_item or is_item_busy: return
	
	var bodies = pickup_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("Grabbable"):
			held_item = body
			is_item_busy = true
			
			if held_item is RigidBody2D:
				held_item.freeze = true
			
			# Smooth Pickup: Reparent while maintaining global position to avoid snapping
			var start_global = held_item.global_position
			held_item.get_parent().remove_child(held_item)
			tomato_hold_point.add_child(held_item)
			held_item.global_position = start_global
			
			# Tween it smoothly into the hold point
			var tween = create_tween()
			tween.tween_property(held_item, "position", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_callback(func(): is_item_busy = false)
			break

func throw_item(dropped: bool = false) -> void:
	if not held_item or is_item_busy: return
	
	is_item_busy = true
	var item_to_throw = held_item
	held_item = null

	## tell the tomato script that it is being thrown so it can know that it is ready to splat
	if "being_thrown" in item_to_throw:
		item_to_throw.being_thrown = true
	
	# Maintain global position during reparenting
	var throw_start_pos = item_to_throw.global_position
	item_to_throw.get_parent().remove_child(item_to_throw)
	get_tree().current_scene.add_child(item_to_throw)
	item_to_throw.global_position = throw_start_pos
	
	if item_to_throw is RigidBody2D:
		item_to_throw.freeze = false
		
		if dropped:
			# Gently toss it up so it drops naturally and doesn't instantly snap downward
			item_to_throw.linear_velocity = Vector2(0, drop_velocity)
		else:
			# Directional throwing utilizing input map axes
			var throw_dir = Input.get_vector("move_left", "move_right", "look_up", "look_down")
			
			if throw_dir == Vector2.ZERO:
				# Default throw arc if standing still
				var dir_x = -1 if anim_sprite.flip_h else 1
				throw_dir = Vector2(dir_x, -0.5).normalized()
			else:
				# Ensure diagonals aren't faster than cardinal directions
				throw_dir = throw_dir.normalized()
			
			item_to_throw.linear_velocity = throw_dir * throw_speed

	is_item_busy = false

func _on_pickup_area_area_entered(area: Area2D) -> void:
	if area.name == "TomatoGrabArea":
		try_pickup()
