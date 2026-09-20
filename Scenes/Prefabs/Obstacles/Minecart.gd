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

# --- WALL DETECTION SETTINGS ---
@export var wall_confirm_frames: int = 2 # a "wall" must be detected this many consecutive physics frames before the cart reverses; filters out single-frame tile-seam glitches on flat floors

@export var minecart_hit_sfx_node_parent: Node
# --- STATE ---
var direction: int = 1
var hit_cooldown_timer: float = 0.0
var _wall_streak: int = 0

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
	floor_constant_speed = true # avoids small speed loss/jitter when crossing tile seams on a "flat" floor

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

	_check_for_wall_bounce()
	_update_rotation()


# Instead of trusting is_on_wall() (which can briefly misfire at tile seams
# on flat ground), inspect this frame's actual collision normals and only
# count something as a wall if it's genuinely steeper than floor_max_angle.
# Requires wall_confirm_frames in a row before reversing, so a one-frame
# glitch from a seam can't cause a jitter-flip.
func _check_for_wall_bounce() -> void:
	var hit_real_wall := false

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()
		# acos of the dot product is an *unsigned* angle from "up," so it
		# behaves identically for left-side and right-side walls, unlike
		# angle_to() which returns a signed angle that differs by side.
		var angle_from_up := rad_to_deg(acos(clamp(normal.dot(Vector2.UP), -1.0, 1.0)))
		if angle_from_up > floor_max_angle_degrees:
			hit_real_wall = true
			break

	if hit_real_wall:
		_wall_streak += 1
	else:
		_wall_streak = 0

	if _wall_streak >= wall_confirm_frames:
		direction *= -1
		_wall_streak = 0


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
