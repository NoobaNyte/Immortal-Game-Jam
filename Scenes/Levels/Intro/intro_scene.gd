extends Node2D

## will start this music on level load
## if this music stream is already playing then do nothing
## if a different music stream is playing then crossfade to this one
@export var music_for_this_level: AudioStream
@export var music_volume_db: float

func _ready() -> void:
	try_start_music()

func try_start_music():
	## if this music stream is already playing then do nothing
	if AudioManager._music_players[AudioManager._active_music_idx].stream == music_for_this_level:
		return

	## if no music playing
	if AudioManager._music_players[AudioManager._active_music_idx].stream == null:
		AudioManager.crossfade_music(music_for_this_level, music_volume_db, 3)
	
	## if a different music stream is playing then crossfade to this one
	else:
		AudioManager.crossfade_music(music_for_this_level, music_volume_db, 3)
