extends Control

@export_file_path var main_scene_file_path

var _swapping := false

func _ready() -> void:
	var err := ResourceLoader.load_threaded_request(main_scene_file_path)
	if err != OK:
		push_error("Failed to start loading main scene: %s" % err)


## loads the main scene and swaps to it once it is completely done loading
func _process(_delta: float) -> void:
	if _swapping:
		return

	var status := ResourceLoader.load_threaded_get_status(main_scene_file_path)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_swapping = true
			var packed: PackedScene = ResourceLoader.load_threaded_get(main_scene_file_path)
			get_tree().change_scene_to_packed(packed)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Main scene failed to load, status: %s" % status)
			set_process(false)
