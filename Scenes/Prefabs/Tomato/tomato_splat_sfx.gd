extends AudioStreamPlayer

func _ready() -> void:
	# Connect the finished signal to automatically free the node
	finished.connect(queue_free)
