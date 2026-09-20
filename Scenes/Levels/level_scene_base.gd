extends Node2D
class_name LevelSceneBase

@onready var player_character: CharacterBody2D = find_child("PlayerCharacter")
@onready var enter_level_area: Area2D = find_child("EnterLevelArea")
@onready var exit_level_area: Area2D = find_child("ExitLevelArea")

@export_file_path var next_level_scene_file_path
@export_file_path var previous_level_scene_file_path

## will start this music on level load
## if this music stream is already playing then do nothing
## if a different music stream is playing then crossfade to this one
@export var music_for_this_level: AudioStream
@export var music_volume_db: float

func _ready() -> void:
	show()
	player_character.show()
	enter_level_area.body_entered.connect(_on_enter_level_area_entered)
	exit_level_area.body_entered.connect(_on_exit_level_area_entered)

	try_start_music()

func try_start_music():
	## if this music stream is already playing then do nothing
	if AudioManager._music_players[AudioManager._active_music_idx].stream == music_for_this_level:
		return

	## if no music playing
	if AudioManager._music_players[AudioManager._active_music_idx].stream == null:
		AudioManager.play_music(music_for_this_level, music_volume_db)
	
	## if a different music stream is playing then crossfade to this one
	else:
		AudioManager.crossfade_music(music_for_this_level, music_volume_db, 3)
	
	
func _on_enter_level_area_entered(body: Node2D):
	if body.name == "PlayerCharacter":
		if previous_level_scene_file_path:
			Global.load_next_level.emit(previous_level_scene_file_path, 0.3, 0.2, true)
		else:
			push_warning("player cannot transition levels! previous_level_scene_file_path not assigned in inspector")

func _on_exit_level_area_entered(body: Node2D):
	print("something exited")
	if body.name == "PlayerCharacter":
		if next_level_scene_file_path:
			Global.load_next_level.emit(next_level_scene_file_path, 0.3, 0.2, true)
		else:
			push_warning("player cannot transition levels! next_level_scene_file_path not assigned in inspector")
