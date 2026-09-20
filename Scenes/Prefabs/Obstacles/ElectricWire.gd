extends Area2D

# --- CYCLE SETTINGS ---
@export var on_duration: float = 2.0
@export var off_duration: float = 2.0
@export var start_active: bool = true

# --- STATE ---
var is_active: bool = true

# --- NODES ---
# Optional - if you have sprite frames/animations named "Active" and "Inactive"
# they'll be played automatically. Leave unassigned if you don't have one yet.
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var cycle_timer: Timer = $CycleTimer


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	cycle_timer.timeout.connect(_on_cycle_timer_timeout)

	is_active = start_active
	_update_visuals()

	cycle_timer.one_shot = true
	cycle_timer.wait_time = on_duration if is_active else off_duration
	cycle_timer.start()


func _on_cycle_timer_timeout() -> void:
	is_active = !is_active
	_update_visuals()

	cycle_timer.wait_time = on_duration if is_active else off_duration
	cycle_timer.start()

	# If we just turned on, catch anyone already standing inside the wire
	# rather than waiting for a fresh body_entered signal.
	if is_active:
		_check_overlapping_bodies()


func _update_visuals() -> void:
	if sprite and sprite.sprite_frames:
		var anim_name := "Active" if is_active else "Inactive"
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)


func _on_body_entered(body: Node) -> void:
	if is_active:
		_try_kill(body)


func _check_overlapping_bodies() -> void:
	for body in get_overlapping_bodies():
		_try_kill(body)


func _try_kill(body: Node) -> void:
	if body.has_method("die"):
		body.die()
