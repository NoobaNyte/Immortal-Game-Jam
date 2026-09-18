extends Node

var _music_players: Array[AudioStreamPlayer] = []
var _active_music_idx: int = 0

var sfx_players: Array[AudioStreamPlayer] = []
## the max number of different sfx that can be played at a time
const SFX_POOL_SIZE := 8

var _music_tween: Tween

func _ready() -> void:
	## Instantiate two music players audio stream nodes to allow for crossfading
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_music_players.append(p)
	
	## instantiate the sfx players audio stream nodes
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)

func crossfade_music(new_stream: AudioStream, new_stream_volume_db: float = 0.0, crossfade_time: float = 1.0) -> void:
	var active_player := _music_players[_active_music_idx]
	var next_idx := (_active_music_idx + 1) % 2
	var next_player := _music_players[next_idx]

	if active_player.stream == new_stream and active_player.playing:
		return

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	## Use parallel tweening so both volume changes happen at the same time
	_music_tween = create_tween().set_parallel(true)

	if active_player.playing:
		## Crossfade: Fade out active, fade in new
		_music_tween.tween_property(active_player, "volume_db", -40.0, crossfade_time)
		_music_tween.tween_callback(active_player.stop).set_delay(crossfade_time)

		next_player.stream = new_stream
		next_player.volume_db = -40.0
		next_player.play()
		_music_tween.tween_property(next_player, "volume_db", new_stream_volume_db, crossfade_time)
	else:
		## No music playing: Fade in new at half the crossfade time
		var half_time := crossfade_time / 2.0
		next_player.stream = new_stream
		next_player.volume_db = -40.0
		next_player.play()
		_music_tween.tween_property(next_player, "volume_db", new_stream_volume_db, half_time)

	## Swap the active player tracker
	_active_music_idx = next_idx

func play_music(stream: AudioStream, volume_db: float = 0.0, fade_out_current_music_before_playing_new_music_time: float = 1.0) -> void:
	var active_player := _music_players[_active_music_idx]

	if active_player.stream == stream and active_player.playing:
		return

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	if fade_out_current_music_before_playing_new_music_time > 0.0 and active_player.playing:
		_music_tween = create_tween()
		_music_tween.tween_property(active_player, "volume_db", -40.0, fade_out_current_music_before_playing_new_music_time)
		_music_tween.tween_callback(func():
			active_player.stream = stream
			active_player.volume_db = volume_db
			active_player.play()
		)
	else:
		active_player.stream = stream
		active_player.volume_db = volume_db
		active_player.play()

func stop_music(fade_time: float = 1.0) -> void:
	var active_player := _music_players[_active_music_idx]

	if not active_player.playing:
		return

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	if fade_time > 0.0:
		_music_tween = create_tween()
		_music_tween.tween_property(active_player, "volume_db", -40.0, fade_time)
		_music_tween.tween_callback(func():
			active_player.stop()
			active_player.volume_db = 0.0 ## reset for next play_music call
		)
	else:
		active_player.stop()
		## also clear the music stream so if statements can check if it is empty properly
		active_player.stream = null

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch_scale
			p.play()
			return
	sfx_players[0].stream = stream
	sfx_players[0].play()