@tool
extends Area2D

# --- WIRE SHAPE SETTINGS ---
@export var sag: float = 40.0          # how much the wire droops at its midpoint
@export var segments: int = 24         # curve resolution - higher = smoother
@export var wire_width: float = 4.0    # visual line thickness
@export var hitbox_padding: float = 3.0 # extra collision width beyond the visual line

# --- CYCLE SETTINGS ---
@export var on_duration: float = 2.0
@export var off_duration: float = 2.0
@export var start_active: bool = true

# --- SPARK SETTINGS ---
@export var spark_speed: float = 300.0 # pixels/sec traveling along the wire

# --- STATE ---
var is_active: bool = true

# --- NODES ---
# PointA / PointB: Marker2D children marking the two ends of the wire.
@onready var point_a: Marker2D = $PointA
@onready var point_b: Marker2D = $PointB
@onready var wire_line: Line2D = $WireLine
@onready var wire_collision: CollisionPolygon2D = $WireCollision
@onready var wire_path: Path2D = $WirePath
@onready var spark_follow: PathFollow2D = $WirePath/SparkFollow
@onready var cycle_timer: Timer = $CycleTimer

# Optional - attach any visual (GPUParticles2D, PointLight2D, Sprite2D...) as a
# child of SparkFollow named "SparkVisual" and it'll be shown/hidden automatically.
@onready var spark_visual: Node = get_node_or_null("WirePath/SparkFollow/SparkVisual")


func _ready() -> void:
	_build_wire_shape()

	# Editor preview mode: build the shape so it's visible while placing points,
	# but skip everything that only makes sense at runtime (signals, timers,
	# death checks). _process() below keeps rebuilding live as you edit.
	if Engine.is_editor_hint():
		return

	body_entered.connect(_on_body_entered)
	cycle_timer.timeout.connect(_on_cycle_timer_timeout)

	is_active = start_active
	_update_active_state()

	cycle_timer.one_shot = true
	cycle_timer.wait_time = on_duration if is_active else off_duration
	cycle_timer.start()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_build_wire_shape()
		return

	if is_active:
		spark_follow.progress += spark_speed * delta
		if spark_follow.progress_ratio >= 1.0:
			spark_follow.progress_ratio = 0.0


func _build_wire_shape() -> void:
	if not point_a or not point_b:
		print("point missing")
		return

	var start_pos: Vector2 = point_a.position
	var end_pos: Vector2 = point_b.position

	var curve_points: PackedVector2Array = PackedVector2Array()
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var pos := start_pos.lerp(end_pos, t)
		pos.y += sag * sin(t * PI) # 0 sag at both ends, max at the midpoint
		curve_points.append(pos)

	# --- Visual line ---
	wire_line.points = curve_points
	wire_line.width = wire_width

	# --- Collision ribbon: offset each curve point left/right by half-width ---
	var half_width := (wire_width * 0.5) + hitbox_padding
	var left_side: PackedVector2Array = PackedVector2Array()
	var right_side: PackedVector2Array = PackedVector2Array()

	for i in range(curve_points.size()):
		var dir: Vector2
		if i == 0:
			dir = (curve_points[1] - curve_points[0]).normalized()
		elif i == curve_points.size() - 1:
			dir = (curve_points[i] - curve_points[i - 1]).normalized()
		else:
			dir = (curve_points[i + 1] - curve_points[i - 1]).normalized()

		var normal := Vector2(-dir.y, dir.x)
		left_side.append(curve_points[i] + normal * half_width)
		right_side.append(curve_points[i] - normal * half_width)

	right_side.reverse()
	var ribbon: PackedVector2Array = left_side + right_side
	wire_collision.polygon = ribbon

	# --- Path for the spark to travel along ---
	var curve := Curve2D.new()
	for point in curve_points:
		curve.add_point(point)
	wire_path.curve = curve


func _on_cycle_timer_timeout() -> void:
	is_active = !is_active
	_update_active_state()

	cycle_timer.wait_time = on_duration if is_active else off_duration
	cycle_timer.start()

	# If we just turned on, catch anyone already standing inside the wire.
	if is_active:
		_check_overlapping_bodies()


func _update_active_state() -> void:
	wire_collision.disabled = not is_active
	spark_follow.visible = is_active

	if spark_visual:
		if spark_visual is GPUParticles2D or spark_visual is CPUParticles2D:
			spark_visual.emitting = is_active
		elif spark_visual.has_method("set_visible"):
			spark_visual.visible = is_active

	wire_line.modulate = Color(1, 1, 1, 1) if is_active else Color(0.5, 0.5, 0.5, 0.6)


func _on_body_entered(body: Node) -> void:
	if is_active:
		_try_kill(body)


func _check_overlapping_bodies() -> void:
	for body in get_overlapping_bodies():
		_try_kill(body)


func _try_kill(body: Node) -> void:
	if body.has_method("die"):
		body.die()
