extends Node2D

@export var tomato_prefab: PackedScene
@onready var reference_tomato_node: RigidBody2D = $ReferenceTomato
@onready var tomato_spawnpoint_options_node_parent: Node2D = $TomatoSpawnpointOptions

func _ready() -> void:
    spawn_tomato()
    if reference_tomato_node:
        reference_tomato_node.queue_free()

func spawn_tomato() -> void:
    if not tomato_prefab:
        return
    
    # 1. Get all Marker2D children from the spawnpoint container
    var spawn_markers = tomato_spawnpoint_options_node_parent.get_children()
    if spawn_markers.is_empty():
        push_warning("No spawn markers found under TomatoSpawnpointOptions!")
        return
        
    # 2. Pick a random marker
    var random_marker = spawn_markers[randi() % spawn_markers.size()]
    
    var tomato_instance = tomato_prefab.instantiate() as RigidBody2D
    add_child(tomato_instance)
    
    # 3. Position the tomato at the random marker's location
    tomato_instance.global_position = random_marker.global_position
    
    # 4. Freeze physics and set scale to zero so it starts invisible/tiny
    tomato_instance.freeze = true
    tomato_instance.scale = Vector2.ZERO
    
    # 5. Tween the scale up (it stays frozen on the vine after growing)
    var tween = create_tween()
    tween.tween_property(tomato_instance, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    
    # Connect to tree_exited
    tomato_instance.tree_exited.connect(func(): _on_tomato_destroyed(tomato_instance))

func _on_tomato_destroyed(tomato: Node) -> void:
    # Only spawn a new one if the tomato was actually queue_freed (picked up/destroyed), 
    # not just temporarily removed/reparented into the player's hands!
    if tomato.is_queued_for_deletion():
        call_deferred("spawn_tomato")