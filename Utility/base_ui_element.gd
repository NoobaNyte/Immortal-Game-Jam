extends Control
class_name BaseUIElement

func wait(seconds: float):
	await get_tree().create_timer(seconds).timeout

func fade_out(control_to_fade: Control, fade_time: float):
	await fade(control_to_fade, fade_time, 0.0)

func fade_in(control_to_fade: Control, fade_time: float):
	await fade(control_to_fade, fade_time, 1.0)

func fade(control_to_fade: Control, fade_time: float, alpha_to_fade_to: float):
	# if the control is fading in make sure it is visible
	if not control_to_fade.visible and control_to_fade.modulate.a == 0 and alpha_to_fade_to > 0.0:
		control_to_fade.show()

	# skip the tween entirely and apply the end state on this frame if the fade time is 0 or less
	if fade_time <= 0.0:
		control_to_fade.modulate.a = alpha_to_fade_to
		if alpha_to_fade_to <= 0.0:
			control_to_fade.hide()
		return

	var tween := create_tween()
	tween.tween_property(control_to_fade, "modulate:a", alpha_to_fade_to, fade_time)

	# if control is fading out then make it hide (which stops mouse blocking)
	if alpha_to_fade_to <= 0.0:
		tween.tween_callback(control_to_fade.hide)

	await tween.finished