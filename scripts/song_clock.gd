extends Node
## The ONLY place the rest of the game reads song time from.
##
## - setup(null, 0)       -> silent mode: plain system clock (dev / no audio)
## - setup(stream, offset)-> local audio: the stream starts when chart time reaches `offset`.
##   Visual time runs on the system clock and is gently pulled toward the audio
##   clock (playback position + mix time - output latency), so it never jumps.
##


var running := false
var _start_usec := 0
var _start_time := 0.0
var _player: AudioStreamPlayer
var _audio_offset := 0.0
var _audio_started := false
var _synced := false
var _bias := 0.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)


func setup(stream: AudioStream, offset: float) -> void:
	_player.stop()
	_player.stream = stream
	_audio_offset = offset
	_audio_started = false
	_synced = false
	_bias = 0.0


func start(from_time: float = 0.0) -> void:
	_start_usec = Time.get_ticks_usec()
	_start_time = from_time
	running = true


func stop() -> void:
	running = false
	_player.stop()


func get_time() -> float:
	if not running:
		return _start_time
	return _sys_time() + _bias


func _sys_time() -> float:
	return _start_time + (Time.get_ticks_usec() - _start_usec) / 1000000.0


func _process(_delta: float) -> void:
	if not running or _player.stream == null:
		return
	if not _audio_started:
		if get_time() >= _audio_offset:
			_player.play()
			_audio_started = true
		return
	if not _player.playing:
		return  # song ended: keep running on system clock with the last bias
	var pos := _player.get_playback_position()
	if pos <= 0.0:
		return
	var audio_time := pos + AudioServer.get_time_since_last_mix() \
		- AudioServer.get_output_latency() + _audio_offset
	var measured := audio_time - _sys_time()
	if not _synced:
		_bias = measured
		_synced = true
	else:
		_bias = lerpf(_bias, measured, 0.05)
