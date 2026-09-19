extends Node2D

@export var tomato_prefab: PackedScene
@onready var reference_tomato_node: RigidBody2D = $ReferenceTomato

func _ready() -> void:
	spawn_tomato()
	reference_tomato_node.queue_free()

func spawn_tomato() -> void:
	if not tomato_prefab:
		return
	
	var tomato_instance = tomato_prefab.instantiate()
	add_child(tomato_instance)
	tomato_instance.position = Vector2.ZERO
	
	# Connect to tree_exited
	tomato_instance.tree_exited.connect(func(): _on_tomato_destroyed(tomato_instance))

func _on_tomato_destroyed(tomato: Node) -> void:
	# Only spawn a new one if the tomato was actually queue_freed (splatted), 
	# not just temporarily removed/reparented into the player's hands!
	if tomato.is_queued_for_deletion():
		call_deferred("spawn_tomato")