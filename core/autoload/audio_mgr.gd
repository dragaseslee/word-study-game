extends Node

var _bgm_player: AudioStreamPlayer
var _bgm_fade_tween: Tween
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_pool_size := 4


func play_bgm(stream: AudioStream, fade_duration: float = 1.0, volume_db: float = 0.0) -> void:
	_ensure_bgm_player()
	if _bgm_player.playing and _bgm_player.stream == stream:
		return
	if fade_duration > 0.0 and _bgm_player.playing:
		_crossfade(stream, fade_duration, volume_db)
	else:
		_bgm_player.stop()
		_bgm_player.stream = stream
		_bgm_player.volume_db = volume_db
		_bgm_player.play()


func stop_bgm(fade_duration: float = 1.0) -> void:
	if _bgm_player == null or not _bgm_player.playing:
		return
	if fade_duration > 0.0:
		_fade_out(fade_duration)
	else:
		_bgm_player.stop()


func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	var player := _get_available_sfx_player()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _ensure_bgm_player() -> void:
	if _bgm_player == null:
		_bgm_player = AudioStreamPlayer.new()
		_bgm_player.bus = &"Music"
		add_child(_bgm_player)


func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	var player := AudioStreamPlayer.new()
	player.bus = &"Master"
	add_child(player)
	_sfx_players.append(player)
	return player


func _crossfade(stream: AudioStream, duration: float, target_db: float) -> void:
	if _bgm_fade_tween != null and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.tween_property(_bgm_player, "volume_db", -40.0, duration * 0.5)
	_bgm_fade_tween.tween_callback(func() -> void:
		_bgm_player.stop()
		_bgm_player.stream = stream
		_bgm_player.volume_db = -40.0
		_bgm_player.play()
	)
	_bgm_fade_tween.tween_property(_bgm_player, "volume_db", target_db, duration * 0.5)


func _fade_out(duration: float) -> void:
	if _bgm_fade_tween != null and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.tween_property(_bgm_player, "volume_db", -40.0, duration)
	_bgm_fade_tween.tween_callback(_bgm_player.stop)
