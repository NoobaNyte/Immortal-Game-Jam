extends LevelSceneBase

@export var music: AudioStream

func _ready() -> void:
	super._ready()
	AudioManager.play_music(music, 15)
