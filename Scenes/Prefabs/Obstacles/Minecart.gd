extends CharacterBody2D

# --- MOVEMENT SETTINGS ---
@export var speed: float = 150.0
@export var gravity: float = 1200.0
@export var max_fall_speed: float = 600.0

# --- KNOCKBACK SETTINGS ---
@export var knockback_speed: float = 5000.0   # horizontal punch, applied in direction of travel
@export var knockback_up_speed: float = -250.0 # negative = upward pop
@export var hit_cooldown: float = 0.75         # prevents re-hitting the same overlap every frame

# --- STATE ---
var direction: int = 1
var hit_cooldown_timer: float = 0.0

# --- NODES ---
# HitArea should be an Area2D child (with its own CollisionShape2D) whose
# collision mask includes the Player's physics layer. It detects the player
# without physically pushing/stopping the cart.
@onready var hit_area: Area2D = $HitArea


func _ready() -> void:
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


func _on_hit_area_body_entered(body: Node) -> void:
	if hit_cooldown_timer > 0.0:
		return

	if body.has_method("apply_knockback"):
		var knock_vector := Vector2(direction * knockback_speed, knockback_up_speed)
		body.apply_knockback(knock_vector)
		hit_cooldown_timer = hit_cooldown
