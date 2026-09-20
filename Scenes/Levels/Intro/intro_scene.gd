extends Node2D


@export_file_path var level_to_go_to_after_intro_scene_file_path
## will start this music on level load
## if this music stream is already playing then do nothing
## if a different music stream is playing then crossfade to this one
@export var music_for_this_level: AudioStream
@export var music_volume_db: float

@export var intro_sprite_textures_in_order: Array[CompressedTexture2D]

@onready var camera: Camera2D = $Camera2D
@export var intro_sprites_texture_rect: TextureRect
@export var sprites_transition_overlay: ColorRect
@export var skip_label: Label

@export var camera_pulse_point: Marker2D

@export var transition_duration: float = 0.5
var current_index: int = 0
var is_transitioning: bool = false
var camera_tween: Tween
var default_camera_pos: Vector2

@export_category("Camera Handheld Settings")
@export var zoom_min: float = 1.02
@export var zoom_max: float = 1.5
@export var pulse_duration_min: float = 5.0
@export var pulse_duration_max: float = 9.0
@export var wobble_distance: float = 35.0
@export var pulse_point_bias: float = 1.0

func _ready() -> void:
    try_start_music()
    
    if intro_sprite_textures_in_order.is_empty():
        push_warning("No intro sprites assigned in the inspector!")
        return
        
    if skip_label:
        skip_label.modulate.a = 0.0
        skip_label.hide()
        
    default_camera_pos = camera.global_position
    
    # Set the first image
    intro_sprites_texture_rect.texture = intro_sprite_textures_in_order[0]
    
    # Start the overlay completely black
    sprites_transition_overlay.modulate.a = 1.0
    sprites_transition_overlay.show()
    
    # Fade out the overlay to reveal the first image
    is_transitioning = true
    await fade_out(sprites_transition_overlay, 1.0)
    
    _randomize_camera_pulse()
    is_transitioning = false
    
    _schedule_skip_label(current_index)

func _unhandled_input(event: InputEvent) -> void:
    # Trigger next slide on left click, Spacebar, or standard UI Accept
    var is_left_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
    var is_spacebar = event is InputEventKey and event.keycode == KEY_SPACE and event.pressed
    
    if is_left_click or is_spacebar or event.is_action_pressed("ui_accept"):
        _next_slide()

func _next_slide() -> void:
    if is_transitioning:
        return
        
    current_index += 1
    
    if current_index >= intro_sprite_textures_in_order.size():
        _finish_intro_sequence()
        return
        
    is_transitioning = true
    
    # Fade out the skip label at the same time as the screen fades to black.
    # Note: We do NOT use 'await' here so it runs in parallel with the overlay fade.
    if skip_label and skip_label.visible:
        fade_out(skip_label, transition_duration)
    
    # 1. Fade to black
    await fade_in(sprites_transition_overlay, transition_duration)
    
    # 2. Wait for 0.5 seconds while faded to black
    await get_tree().create_timer(0.5).timeout
    
    # 3. Swap the image and reset camera while the screen is black
    intro_sprites_texture_rect.texture = intro_sprite_textures_in_order[current_index]
    
    if camera_tween:
        camera_tween.kill()
    camera.zoom = Vector2.ONE
    camera.global_position = default_camera_pos
    
    # 4. Fade back to clear to reveal the new image
    await fade_out(sprites_transition_overlay, transition_duration)
    
    _randomize_camera_pulse()
    is_transitioning = false
    
    # Start the 3-second timer for the label again
    _schedule_skip_label(current_index)

func _schedule_skip_label(expected_index: int) -> void:
    await get_tree().create_timer(3.0).timeout
    
    # Only fade in the label if the user hasn't clicked to the next slide yet
    if expected_index == current_index and not is_transitioning and skip_label:
        await fade_in(skip_label, 0.5)

func _randomize_camera_pulse() -> void:
    if not is_inside_tree():
        return
        
    if camera_tween:
        camera_tween.kill()
        
    camera_tween = create_tween()

    # 1. Random Zoom
    var target_zoom_val = randf_range(zoom_min, zoom_max)
    var target_zoom_vec = Vector2(target_zoom_val, target_zoom_val)

    # 2. Calculate Strict Bounds
    var max_x_offset = 960.0 * (1.0 - (1.0 / target_zoom_val))
    var max_y_offset = 540.0 * (1.0 - (1.0 / target_zoom_val))

    var min_x = default_camera_pos.x - max_x_offset
    var max_x = default_camera_pos.x + max_x_offset
    var min_y = default_camera_pos.y - max_y_offset
    var max_y = default_camera_pos.y + max_y_offset

    # 3. Calculate Target Position
    var target_pos = default_camera_pos

    if camera_pulse_point:
        target_pos = default_camera_pos.lerp(camera_pulse_point.global_position, pulse_point_bias)
        
    var drift_x = randf_range(-wobble_distance, wobble_distance)
    var drift_y = randf_range(-wobble_distance, wobble_distance)
    target_pos += Vector2(drift_x, drift_y)

    # 4. Clamp Position
    target_pos.x = clamp(target_pos.x, min_x, max_x)
    target_pos.y = clamp(target_pos.y, min_y, max_y)

    # 5. Movement Execution
    var move_duration = randf_range(pulse_duration_min, pulse_duration_max)

    camera_tween.set_parallel(true)

    camera_tween.tween_property(camera, "zoom", target_zoom_vec, move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    camera_tween.tween_property(camera, "global_position", target_pos, move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

    camera_tween.set_parallel(false)
    camera_tween.tween_callback(_randomize_camera_pulse)

func _finish_intro_sequence() -> void:
    is_transitioning = true
    
    # Fade out the label one final time if it's visible
    if skip_label and skip_label.visible:
        fade_out(skip_label, transition_duration)
        
    await fade_in(sprites_transition_overlay, transition_duration)
    
    if camera_tween:
        camera_tween.kill()
        
    Global.load_next_level.emit(level_to_go_to_after_intro_scene_file_path, 0, 0.5)

# --- FADE HELPERS ---

func fade_in(control_to_fade: Control, fade_time: float):
    control_to_fade.show()
    var tween = create_tween()
    tween.tween_property(control_to_fade, "modulate:a", 1.0, fade_time)
    await tween.finished

func fade_out(control_to_fade: Control, fade_time: float):
    var tween = create_tween()
    tween.tween_property(control_to_fade, "modulate:a", 0.0, fade_time)
    tween.tween_callback(control_to_fade.hide)
    await tween.finished

# --- MUSIC LOGIC ---

func try_start_music():
    if AudioManager._music_players[AudioManager._active_music_idx].stream == music_for_this_level:
        return

    if AudioManager._music_players[AudioManager._active_music_idx].stream == null:
        AudioManager.crossfade_music(music_for_this_level, music_volume_db, 3)
    else:
        AudioManager.crossfade_music(music_for_this_level, music_volume_db, 3)