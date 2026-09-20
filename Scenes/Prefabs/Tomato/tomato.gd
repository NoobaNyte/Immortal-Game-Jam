@tool
extends RigidBody2D

@export var light_color: GradientTexture2D:
	set(value):
		light_color = value
		_update_colors()

@export var base_color: GradientTexture2D:
	set(value):
		base_color = value
		_update_colors()

@export var stem_color: Color:
	set(value):
		stem_color = value
		_update_colors()

@export var splat_prefab: PackedScene

@export var tomato_splat_blob_color: Color

@export var tomato_splat_sfx_player: AudioStreamPlayer

@onready var tomato_point_light: PointLight2D = $TomatoPointLight2D
@onready var tomato_base_fill: Polygon2D = $Mesh/TomatoBaseFill
@onready var tomato_stem_bottom_fill: Polygon2D = $Mesh/TomatoStemBottomFill
@onready var tomato_stem_top_fill: Polygon2D = $Mesh/TomatoStemTopFill

@onready var pick_tomato_sfx: AudioStreamPlayer = $PickTomatoSFX


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
	if tomato_point_light:
		tomato_point_light.texture = light_color
	if tomato_base_fill:
		tomato_base_fill.texture = base_color
	if tomato_stem_bottom_fill:
		tomato_stem_bottom_fill.color = stem_color
	if tomato_stem_top_fill:
		tomato_stem_top_fill.color = stem_color

func play_pick_up_tomato_sfx() -> void:
	if pick_tomato_sfx:
		pick_tomato_sfx.pitch_scale = randf_range(1.2, 1.5)
		pick_tomato_sfx.play()
		

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if being_thrown and state.get_contact_count() > 0:
		being_thrown = false
		
		var surface_normal = state.get_contact_local_normal(0)
		
		# Grab the exact, true global position directly from the physics engine
		var contact_point = state.transform.origin
		
		call_deferred("splat", surface_normal, contact_point)


func splat(surface_normal: Vector2, contact_point: Vector2) -> void:
	if splat_prefab:
		## play tomato splat sfx
		tomato_splat_sfx_player.reparent(get_tree().current_scene)
		tomato_splat_sfx_player.play()
		#AudioManager.play_sfx(tomato_splat_sfx, -12, randf_range(0.55, 0.7))

		var splat_instance = splat_prefab.instantiate()
		get_tree().current_scene.add_child(splat_instance)
		
		# Fire the new setup method
		if splat_instance.has_method("setup_splat"):
			splat_instance.setup_splat(linear_velocity, tomato_splat_blob_color, surface_normal, contact_point)
			
	queue_free()
