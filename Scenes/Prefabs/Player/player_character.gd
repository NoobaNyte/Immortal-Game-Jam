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

# --- HITBOX SETTINGS ---
@export var mortal_extents := Vector2(10, 20)
@export var bat_extents := Vector2(12, 8)

# --- THROW / PICKUP ---
var held_item: Node2D = null
var throw_force := Vector2(400, -300)

# --- NODES ---
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
# Assuming you have an Area2D to detect items to pick up
@onready var pickup_area: Area2D = $PickupArea

## collision shapes
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@export var player_collision_shape: CapsuleShape2D
@export var bat_collision_shape: CapsuleShape2D

## player light so when you swap to bat the light energy gets updated
@onready var player_point_light: PointLight2D = $PlayerPointLight2D
@onready var original_player_point_light_energy: float = player_point_light.energy

func _ready():
	anim_sprite.play("PlayerIdle")

func _physics_process(delta: float) -> void:
	handle_gravity(delta)
	handle_jump(delta)
	handle_movement(delta)
	
	move_and_slide()
	update_animations()

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		var current_gravity = gravity
		
		# Make the character fall faster for weightier movement (Silksong style)
		if velocity.y > 0 and not is_bat_mode:
			current_gravity *= fall_gravity_multiplier
			
		velocity.y += current_gravity * delta
		
		# Terminal velocity limits
		var terminal_velocity = bat_fall_speed if is_bat_mode else max_fall_speed
		if velocity.y > terminal_velocity:
			velocity.y = terminal_velocity

func handle_jump(delta: float) -> void:
	# Coyote Time logic
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	# Variable Jump Height (If jump button is released early, cut the velocity)
	if Input.is_action_just_released("jump") and velocity.y < min_jump_velocity and not is_bat_mode:
		velocity.y = min_jump_velocity

	# Handle the Jump Input
	if Input.is_action_just_pressed("jump"):
		if is_bat_mode:
			# Infinite jumps / flaps in bat mode
			velocity.y = bat_flap_velocity
		elif coyote_timer > 0.0:
			# Mortal jump
			velocity.y = max_jump_velocity
			coyote_timer = 0.0 # Consume coyote time

func handle_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	
	if direction != 0:
		# Snappy acceleration
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		# Flip sprite
		anim_sprite.flip_h = direction < 0
	else:
		# Snappy deceleration (friction)
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func update_animations() -> void:
	# Basic animation state machine
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
		## change sprite
		anim_sprite.play("BatIdle")

		## update light
		player_point_light.energy = 0.1

		# Shrink/change collision box for bat mode
		collision_shape.shape = bat_collision_shape
		# Optional: give a tiny boost when transforming
		velocity.y = bat_flap_velocity / 2.0

		# Drop held items when turning into a bat
		if held_item:
			throw_item(true)
	else:
		## change sprite
		anim_sprite.play("PlayerIdle")

		## update light
		player_point_light.energy = original_player_point_light_energy

		# Revert to mortal collision box
		collision_shape.shape = player_collision_shape

func try_pickup() -> void:
	# Can't pick up things in bat mode
	if is_bat_mode or not pickup_area: return
	
	var bodies = pickup_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("pickable"):
			held_item = body
			# Logic to attach the item to the player
			held_item.get_parent().remove_child(held_item)
			add_child(held_item)
			held_item.position = Vector2(0, -20) # Hold above head
			
			# Disable item physics while holding
			if held_item is RigidBody2D:
				held_item.freeze = true
			break

func throw_item(dropped: bool = false) -> void:
	if not held_item: return
	
	var item_to_throw = held_item
	held_item = null
	
	remove_child(item_to_throw)
	get_tree().current_scene.add_child(item_to_throw)
	
	item_to_throw.global_position = global_position + Vector2(0, -20)
	
	if item_to_throw is RigidBody2D:
		item_to_throw.freeze = false
		
		if not dropped:
			# Determine throw direction based on sprite facing
			var dir_x = -1 if anim_sprite.flip_h else 1
			item_to_throw.linear_velocity = Vector2(throw_force.x * dir_x, throw_force.y)
