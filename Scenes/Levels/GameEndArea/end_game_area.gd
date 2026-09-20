extends LevelSceneBase

@export var end_game_area_anim_player: AnimationPlayer
@export var player: CharacterBody2D

@export var sun_point_light: PointLight2D
@export var sun_start_scale: float = 50.0 ## The final scale of the sun light when winning
@export var sun_target_scale: float = 3.0 ## The final scale of the sun light when winning
@export var sun_scale_duration: float = 10 ## How long the scale tween takes

@export_category("Bat Swarm Settings")
@export var bat_sfx: AudioStream
@export var bat_texture: CompressedTexture2D
@export var bat_swarm_start_location: Marker2D

@export var bat_swarm_count: int = 50 ## Increased count for a longer stream
@export var bat_swarm_duration: float = 4 ## How many seconds the swarm keeps coming
@export var bat_min_speed: float = 900.0
@export var bat_max_speed: float = 1300.0

@export var player_ash_particles: CPUParticles2D
@export_file_path var beginning_scene_file_path


func _ready() -> void:
	super._ready()
	sun_point_light.scale.x = sun_start_scale
	sun_point_light.scale.y = sun_start_scale

func _on_win_area_body_entered(body: Node2D) -> void:
	if not body.name == "PlayerCharacter":
		return
	

	player.disable_input = true
	if player.is_bat_mode:
		player.toggle_bat_mode()

	if not sun_point_light:
		return

	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	
	var target_vector = Vector2(sun_target_scale, sun_target_scale)
	tween.tween_property(sun_point_light, "scale", target_vector, sun_scale_duration).set_trans(Tween.TRANS_LINEAR)

	# Optionally ramp up the energy linearly so it feels active for the whole duration
	tween.tween_property(sun_point_light, "energy", sun_point_light.energy * 4.0, sun_scale_duration).set_trans(Tween.TRANS_LINEAR)

	end_game_area_anim_player.play("EndGameAnimations/SendBatSwarm")

	await tween.finished

	end_game_area_anim_player.play("EndGameAnimations/EndGame")

func play_bat_sfx():
	AudioManager.play_sfx(bat_sfx)

func send_swarm_of_bats() -> void:
	if not bat_texture or not bat_swarm_start_location:
		push_warning("Bat texture or swarm start location is not assigned!")
		return

	# Calculate how long to wait between each bat spawning
	var spawn_delay = bat_swarm_duration / float(bat_swarm_count)

	for i in range(bat_swarm_count):
		var bat = Sprite2D.new()
		bat.texture = bat_texture
		
		var angle = randf() * TAU
		var distance = sqrt(randf()) * 200.0
		var random_offset = Vector2(cos(angle), sin(angle)) * distance
		
		bat.global_position = bat_swarm_start_location.global_position + random_offset
		
		var bat_script = GDScript.new()
		
		bat_script.source_code = """
		extends Sprite2D

		var fly_speed: float = 1000.0
		var bob_amplitude: float = 15.0
		var bob_frequency: float = 10.0
		var time_offset: float = 0.0
		var base_y: float = 0.0
		var elapsed_time: float = 0.0

		func _ready() -> void:
			base_y = global_position.y
			time_offset = randf() * 20.0

		func _process(delta: float) -> void:
			elapsed_time += delta
			global_position.x -= fly_speed * delta
			global_position.y = base_y + sin((elapsed_time + time_offset) * bob_frequency) * bob_amplitude
			
			if global_position.x < -6000:
				queue_free()
		""".dedent()
		
		bat_script.reload()
		bat.set_script(bat_script)
		
		bat.fly_speed = randf_range(bat_min_speed, bat_max_speed)
		bat.bob_amplitude = randf_range(8.0, 22.0)
		bat.bob_frequency = randf_range(8.0, 14.0)
		
		get_tree().current_scene.add_child(bat)
		
		# Pause the loop for a tiny fraction of a second before spawning the next bat
		if spawn_delay > 0.0:
			await get_tree().create_timer(spawn_delay).timeout

func toggle_bat_mode_on_player():
	player.find_child("PlayerPointLight2D").queue_free()
	player.gravity = 0
	player.disable_sfx = true
	player.disable_anim_player = true
	player.anim_sprite.play("BatFlap") # [cite: 1]

	var white_shader = Shader.new()
	white_shader.code = """
	shader_type canvas_item;
	uniform float whiteness : hint_range(0.0, 1.0) = 0.0;
	uniform float alpha_mult : hint_range(0.0, 1.0) = 1.0;

	void fragment() {
		vec4 tex_color = texture(TEXTURE, UV);
		vec4 blended_color = mix(tex_color, vec4(1.0, 1.0, 1.0, tex_color.a), whiteness);
		
		// Apply the alpha multiplier to the final color
		blended_color.a *= alpha_mult;
		COLOR = blended_color;
	}
	"""

	var mat = ShaderMaterial.new()
	mat.shader = white_shader
	player.anim_sprite.material = mat # [cite: 1]

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_interval(6)

	# 1. Tween whiteness to 1.0 over the full 20 seconds
	tween.tween_method(
		func(value: float): mat.set_shader_parameter("whiteness", value),
		0.0,
		1.0,
		18.0
	).set_trans(Tween.TRANS_LINEAR)

	# 2. Tween alpha to 0.0 over 2 seconds, but delay it until 18 seconds in
	tween.tween_method(
		func(value: float): mat.set_shader_parameter("alpha_mult", value),
		1.0,
		0.0,
		2.0
	).set_delay(16.0).set_trans(Tween.TRANS_LINEAR)

	await get_tree().create_timer(17).timeout
	player_ash_particles.reparent(self)
	player_ash_particles.emitting = true


func _on_end_restart_button_pressed() -> void:
	Global.load_next_level.emit(beginning_scene_file_path)
