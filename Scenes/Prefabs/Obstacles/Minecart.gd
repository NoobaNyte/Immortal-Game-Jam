extends CharacterBody2D

# --- MOVEMENT SETTINGS ---
@export var speed: float = 150.0
@export var gravity: float = 1200.0
@export var max_fall_speed: float = 600.0

# --- KNOCKBACK SETTINGS ---
@export var knockback_speed: float = 500.0 # horizontal punch, applied in direction of travel
@export var knockback_up_speed: float = -250.0 # negative = upward pop
@export var hit_cooldown: float = 0.25 # prevents re-hitting the same overlap every frame

# --- SLOPE HANDLING SETTINGS ---
@export var floor_max_angle_degrees: float = 65.0 # steeper than this counts as a wall (triggers the bounce below)
@export var floor_snap_distance: float = 8.0 # keeps the cart glued to the floor across small bumps/tile seams
@export var safe_margin_distance: float = 0.5 # extra slack for collision detection at tile seams (default is 0.08, quite tight)


@export var minecart_hit_sfx_node_parent: Node
# --- STATE ---
var direction: int = 1
var hit_cooldown_timer: float = 0.0

# --- NODES ---
# HitArea should be an Area2D child (with its own CollisionShape2D) whose
# collision mask includes the Player's physics layer. It detects the player
# without physically pushing/stopping the cart. Since it's a child of the
# root, it will rotate along with the whole cart on slopes.
@onready var hit_area: Area2D = $HitArea


func _ready() -> void:
	floor_max_angle = deg_to_rad(floor_max_angle_degrees)
	floor_snap_length = floor_snap_distance
	safe_margin = safe_margin_distance
	floor_stop_on_slope = false

	if hit_area:
		hit_area.body_entered.connect(_on_hit_area_body_entered)
	else:
		push_warning("Minecart: no HitArea child found. Player knockback won't work.")


func _physics_process(delta: float) -> void:
	if hit_cooldown_timer > 0.0:
		hit_cooldown_timer -= delta

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)

	velocity.x = speed * direction

	move_and_slide()

	# Bounce off anything steeper than the CharacterBody2D's Floor Max Angle
	# (walls, dead ends). Slopes within that angle are treated as floor and
	# just followed, not bounced off of.
	if is_on_wall():
		direction *= -1

	_update_rotation()


func _update_rotation() -> void:
	if is_on_floor():
		# get_floor_normal() points straight up (0,-1) on flat ground, and
		# tilts to match the slope otherwise. +PI/2 converts that normal
		# into the matching surface angle. This is a world-space value, so
		# it's unaffected by the body's own current rotation.
		rotation = get_floor_normal().angle() + PI / 2.0


func _on_hit_area_body_entered(body: Node) -> void:
	#print("HitArea touched: ", body.name)
	if hit_cooldown_timer > 0.0:
		return

	if body.has_method("apply_knockback"):
		play_minecart_hit_sfx()
		var knock_vector := Vector2(direction * knockback_speed * speed, knockback_up_speed)
		body.apply_knockback(knock_vector)
		hit_cooldown_timer = hit_cooldown

func play_minecart_hit_sfx():
	if not minecart_hit_sfx_node_parent:
		return
		
	# Get all audio player children from the parent node
	var sfx_children = minecart_hit_sfx_node_parent.get_children()
	if sfx_children.is_empty():
		return
		
	# Pick a random node from the list
	var random_sfx = sfx_children.pick_random() as AudioStreamPlayer
	if random_sfx:
		# Apply random pitch variation and play
		random_sfx.pitch_scale = randf_range(0.9, 1.1)
		random_sfx.play()