extends BaseUIElement
class_name LevelUI

@onready var go_back_button: Button = $GoBackButton
@onready var pause_menu: Control = $PauseMenu
@onready var controls_menu: Control = $ControlsMenu
@onready var settings_menu: Control = $SettingsMenu

# New Audio Slider Exports
@export var master_audio_slider: HSlider
@export var music_audio_slider: HSlider
@export var sfx_audio_slider: HSlider

var menu_stack: Array[Control] = []
var is_transitioning: bool = false
var fade_duration: float = 0.25

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    
    # Instantly hide all menus and buttons to start
    fade_out(pause_menu, 0.0)
    fade_out(controls_menu, 0.0)
    fade_out(settings_menu, 0.0)
    fade_out(go_back_button, 0.0)
    
    # Initialize and connect the audio sliders
    setup_audio_slider(master_audio_slider, "Master")
    setup_audio_slider(music_audio_slider, "Music")
    setup_audio_slider(sfx_audio_slider, "SFX")

func setup_audio_slider(slider: HSlider, bus_name: String) -> void:
    if not slider:
        return
        
    var bus_index = AudioServer.get_bus_index(bus_name)
    if bus_index == -1:
        push_warning("Audio bus not found: ", bus_name)
        return
        
    # Set initial slider position so current bus volume sits at 70% of the slider
    var current_db = AudioServer.get_bus_volume_db(bus_index)
    var current_linear = db_to_linear(current_db)
    slider.value = current_linear * 0.7 * slider.max_value
    
    # Connect value changes
    slider.value_changed.connect(func(value): _on_audio_slider_changed(value, bus_name, slider))

func _on_audio_slider_changed(value: float, bus_name: String, slider: HSlider) -> void:
    var bus_index = AudioServer.get_bus_index(bus_name)
    if bus_index == -1:
        return
        
    if value <= 0.0:
        AudioServer.set_bus_mute(bus_index, true)
    else:
        AudioServer.set_bus_mute(bus_index, false)
        
        # 70% of the slider corresponds to 0 dB (linear 1.0)
        var slider_ratio = value / slider.max_value
        var linear_val = slider_ratio / 0.7
        var db_val = linear_to_db(linear_val)
        
        AudioServer.set_bus_volume_db(bus_index, db_val)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        if is_transitioning:
            return
        
        # If no menus are open, open the UI. Otherwise, use it to go back.
        if menu_stack.is_empty():
            open_ui()
        else:
            go_back()

func open_ui() -> void:
    is_transitioning = true
    get_tree().paused = true # Pause the game engine
    
    menu_stack.push_back(pause_menu)
    
    # Fade in the pause menu and back button simultaneously 
    fade_in(go_back_button, fade_duration)
    await fade_in(pause_menu, fade_duration)
    
    is_transitioning = false

func close_ui() -> void:
    is_transitioning = true
    
    # Fade out the back button
    fade_out(go_back_button, fade_duration)
    
    # Fade out whatever the current open menu is
    if menu_stack.size() > 0:
        var current_menu = menu_stack.pop_back()
        await fade_out(current_menu, fade_duration)
        
    menu_stack.clear()
    get_tree().paused = false # Unpause the game engine
    is_transitioning = false

func transition_to_menu(next_menu: Control) -> void:
    # Prevent spamming or transitioning to the menu we are already on
    if is_transitioning or (menu_stack.size() > 0 and menu_stack.back() == next_menu):
        return
        
    is_transitioning = true
    
    # Fade out the current menu
    if menu_stack.size() > 0:
        var current_menu = menu_stack.back()
        await fade_out(current_menu, fade_duration)
        
    # Push new menu to history and fade it in
    menu_stack.push_back(next_menu)
    await fade_in(next_menu, fade_duration)
    
    is_transitioning = false

func go_back() -> void:
    if is_transitioning:
        return
        
    # If we are at the very first menu (the Pause Menu), close the UI completely
    if menu_stack.size() <= 1:
        close_ui()
    else:
        is_transitioning = true
        
        # Pop the current menu off the stack and fade it out
        var current_menu = menu_stack.pop_back()
        await fade_out(current_menu, fade_duration)
        
        # Grab the previous menu (which is now at the top of the stack) and fade it in
        var previous_menu = menu_stack.back()
        await fade_in(previous_menu, fade_duration)
        
        is_transitioning = false

# --- Button Connections ---

func _on_go_back_button_pressed() -> void:
    go_back()

func _on_settings_button_pressed() -> void:
    transition_to_menu(settings_menu)

func _on_controls_info_button_pressed() -> void:
    transition_to_menu(controls_menu)

func _on_exit_game_button_pressed() -> void:
    get_tree().quit()

func _on_continue_button_pressed() -> void:
    go_back()
