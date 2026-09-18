extends Node2D

@onready var level_container: Node2D = $LevelContainer
@onready var loading_screen: Control = $PersistentUI/LoadingScreen

var current_level_node: Node = null
var is_loading := false

func _ready() -> void:
	Global.load_next_level.connect(load_level)

	## hide the loading screen to make sure it doesn't start shown
	loading_screen.fade_out(loading_screen, 0)

	## register any level that is currently in the level container as the current level
	## this allows you to test levels (still able to use the level loading system) by just putting them inside the level container
	if level_container.get_child(0) != null:
		current_level_node = level_container.get_child(0)
	
	
func load_level(next_level_path: String, loading_screen_fade_in_time: float = 0.0, loading_screen_fade_out_time: float = 0.0) -> void:
	if is_loading:
		return
	is_loading = true

	await loading_screen.fade_in(loading_screen, loading_screen_fade_in_time)

	ResourceLoader.load_threaded_request(next_level_path)

	## minimum loading screen time (change number inside create_timer parenthesis)
	var min_timer := get_tree().create_timer(0)

	## gets filled in-place by load_threaded_get_status with progress[0] as a float 0.0-1.0
	var progress: Array = []

	while true:
		var status := ResourceLoader.load_threaded_get_status(next_level_path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		elif status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			push_error("Failed to load level: " + next_level_path)
			is_loading = false
			loading_screen.hide()
			return
		await get_tree().physics_frame

	if min_timer.time_left > 0.0:
		await min_timer.timeout

	var level_resource: PackedScene = ResourceLoader.load_threaded_get(next_level_path)

	if current_level_node != null:
		current_level_node.queue_free()
		current_level_node = null

	current_level_node = level_resource.instantiate()
	level_container.add_child(current_level_node)

	## everything is fully loaded and instantiated by this point, so no need to await the fade out
	loading_screen.fade_out(loading_screen, loading_screen_fade_out_time)
	is_loading = false
