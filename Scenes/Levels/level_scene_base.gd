extends Node2D
class_name LevelSceneBase

@onready var player_character: CharacterBody2D = find_child("PlayerCharacter")
@onready var enter_level_area: Area2D = find_child("EnterLevelArea")
@onready var exit_level_area: Area2D = find_child("ExitLevelArea")

@onready var player_level_enter_point: Marker2D = find_child("PlayerLevelEnterPoint")
@onready var player_level_exit_point: Marker2D = find_child("PlayerLevelExitPoint")

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
	enter_level_area.area_exited.connect(_on_transition_area_exited)
	exit_level_area.area_exited.connect(_on_transition_area_exited)

	try_start_music()

	## spawn the player in
	var target_spawn_pos: Vector2 = Vector2.ZERO

	match Global.player_transition_state:
		Global.PlayerTransitionState.FROM_ENTRANCE:
			target_spawn_pos = player_level_exit_point.global_position
		Global.PlayerTransitionState.FROM_EXIT:
			target_spawn_pos = player_level_enter_point.global_position

	# Calculate the distance from the player's center origin to the bottom of its collision shape
	var bottom_offset_y: float = 0.0
	if player_character.collision_shape and player_character.collision_shape.shape:
		var shape = player_character.collision_shape.shape
		if shape is CapsuleShape2D:
			# Capsule height / 2 + any local Y offset of the collision shape node itself
			bottom_offset_y = (shape.height / 2.0) + player_character.collision_shape.position.y
		elif shape is RectangleShape2D:
			bottom_offset_y = (shape.size.y / 2.0) + player_character.collision_shape.position.y

	# Offset the player's position upward so its feet sit exactly on the marker point
	target_spawn_pos = target_spawn_pos - Vector2(0, bottom_offset_y)
	player_character.global_position = target_spawn_pos
	
	## determine whether the player is inside an area
	## if player is not inside a transition area after this, immediately set transitioning bool to false
	# Point this to an Area2D child node inside your player character
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player_sensor_area: Area2D = player_character.get_node("PickupArea") # or "DetectionArea"

	if player_sensor_area:
		var overlapping_areas = player_sensor_area.get_overlapping_areas()
		
		if overlapping_areas.is_empty():
			print("false empty")
			Global.player_is_transitioning = false
		else:
			var only_in_transition_areas = true
			for area in overlapping_areas:
				if not area.is_in_group("TransitionArea"):
					only_in_transition_areas = false
					break
			
			# Only set to false if ALL overlapping areas are NOT transition areas
			if only_in_transition_areas:
				# They are only touching transition areas, keep transitioning true (or handle as needed)
				pass
			else:
				print("false")
				Global.player_is_transitioning = false


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
		## don't transition the player if they just entered the scene
		if Global.player_is_transitioning:
			return

		if previous_level_scene_file_path:
			Global.set_player_transition_state(Global.PlayerTransitionState.FROM_ENTRANCE)
			Global.load_next_level.emit(previous_level_scene_file_path, 0.3, 0.2, true)
		else:
			push_warning("player cannot transition levels! previous_level_scene_file_path not assigned in inspector")

func _on_exit_level_area_entered(body: Node2D):
	if body.name == "PlayerCharacter":
		## don't transition the player if they just entered the scene
		if Global.player_is_transitioning:
			return
		if next_level_scene_file_path:
			Global.set_player_transition_state(Global.PlayerTransitionState.FROM_EXIT)
			Global.load_next_level.emit(next_level_scene_file_path, 0.3, 0.2, true)
		else:
			push_warning("player cannot transition levels! next_level_scene_file_path not assigned in inspector")

## for if you spawn inside a transition area
func _on_transition_area_exited(area: Area2D):
	if area.name == "PickupArea":
		if area.get_parent().name == "PlayerCharacter":
			Global.player_is_transitioning = false
