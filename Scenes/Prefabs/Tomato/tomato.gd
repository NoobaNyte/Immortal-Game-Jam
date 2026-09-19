@tool
extends Node2D

@export var base_color: Color:
	set(value):
		base_color = value
		_update_colors()

@export var stem_color: Color:
	set(value):
		stem_color = value
		_update_colors()

@onready var tomato_base_fill: Polygon2D = $TomatoBaseFill
@onready var tomato_stem_bottom_fill: Polygon2D = $TomatoStemBottomFill
@onready var tomato_stem_top_fill: Polygon2D = $TomatoStemTopFill

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