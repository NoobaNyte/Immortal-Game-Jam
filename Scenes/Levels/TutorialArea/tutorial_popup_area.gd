extends Area2D

@export var control_to_fade_in: Control
@export var fade_duration: float = 0.5

func _ready() -> void:
	if control_to_fade_in:
		control_to_fade_in.modulate.a = 0.0
		control_to_fade_in.hide()
		
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "PlayerCharacter" and control_to_fade_in:
		print("entered")
		fade_in(control_to_fade_in, fade_duration)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "PlayerCharacter" and control_to_fade_in:
		fade_out(control_to_fade_in, fade_duration)

# --- FADE HELPERS ---

func fade_in(control_to_fade: Control, fade_time: float) -> void:
	control_to_fade.show()
	var tween = create_tween()
	tween.tween_property(control_to_fade, "modulate:a", 1.0, fade_time)

func fade_out(control_to_fade: Control, fade_time: float) -> void:
	var tween = create_tween()
	tween.tween_property(control_to_fade, "modulate:a", 0.0, fade_time)
	tween.tween_callback(control_to_fade.hide)
