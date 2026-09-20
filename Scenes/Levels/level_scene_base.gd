extends Node2D
class_name LevelSceneBase

@onready var player_character: CharacterBody2D = find_child("PlayerCharacter")
@onready var enter_level_area: Area2D = find_child("EnterLevelArea")
@onready var exit_level_area: Area2D = find_child("ExitLevelArea")

@export_file_path var next_level_scene_file_path
@export_file_path var previous_level_scene_file_path

func _ready() -> void:
	player_character.show()
	enter_level_area.body_entered.connect(_on_enter_level_area_entered)
	exit_level_area.body_entered.connect(_on_exit_level_area_entered)

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