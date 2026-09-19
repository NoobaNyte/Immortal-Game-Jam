@tool
extends RigidBody2D

@export var base_color: Color:
	set(value):
		base_color = value
		_update_colors()

@export var stem_color: Color:
	set(value):
		stem_color = value
		_update_colors()

@export var splat_prefab: PackedScene

@onready var tomato_base_fill: Polygon2D = $Mesh/TomatoBaseFill
@onready var tomato_stem_bottom_fill: Polygon2D = $Mesh/TomatoStemBottomFill
@onready var tomato_stem_top_fill: Polygon2D = $Mesh/TomatoStemTopFill

## set to true by player_character.gd
var being_thrown: bool = false:
	set(value):
		being_thrown = value
		if being_thrown:
			# Enable contact monitoring so body_entered signal triggers
			contact_monitor = true
			max_contacts_reported = 4


func _ready() -> void:
	_update_colors()
	
func _update_colors() -> void:
	# Null checks are required because setters can run 
	# before @onready variables are fully initialized in the editor.
	if tomato_base_fill:
		tomato_base_fill.color = base_color
	if tomato_stem_bottom_fill:
		tomato_stem_bottom_fill.color = stem_color
	if tomato_stem_top_fill:
		tomato_stem_top_fill.color = stem_color


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Check if it hit something while being thrown
	if being_thrown and state.get_contact_count() > 0:
		being_thrown = false
		
		# Extract the exact wall/floor normal from the physics state
		var surface_normal = state.get_contact_local_normal(0)
		
		# Extract the exact impact point (Despite the name 'local', this returns global coordinates)
		var contact_point = state.get_contact_local_position(0)
		
		# Safely defer the splat call, passing both the normal and the contact point
		call_deferred("splat", surface_normal, contact_point)

func splat(surface_normal: Vector2, contact_point: Vector2) -> void:
	if splat_prefab:
		var splat_instance = splat_prefab.instantiate()
		get_tree().current_scene.add_child(splat_instance)
		
		# Set the splat to the exact collision point on the wall/floor
		splat_instance.global_position = contact_point
		
		if splat_instance.has_method("setup_splat"):
			splat_instance.setup_splat(linear_velocity, base_color, surface_normal)
			
	queue_free()