extends Node2D
class_name LevelSceneBase

@onready var player_character: CharacterBody2D = find_child("PlayerCharacter")

func _ready() -> void:
	player_character.show()