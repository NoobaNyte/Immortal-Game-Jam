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
	
	# Connect to the body_entered signal dynamically
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _update_colors() -> void:
	# Null checks are required because setters can run 
	# before @onready variables are fully initialized in the editor.
	if tomato_base_fill:
		tomato_base_fill.color = base_color
	if tomato_stem_bottom_fill:
		tomato_stem_bottom_fill.color = stem_color
	if tomato_stem_top_fill:
		tomato_stem_top_fill.color = stem_color

func _on_body_entered(_body: Node) -> void:
	# Only splat if it's currently flagged as being thrown
	if being_thrown:
		splat()

func splat() -> void:
	# Placeholder for future particle effects or animations; queue_free for now
	print("tomato splatting!")
	queue_free()