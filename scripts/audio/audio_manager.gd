extends AudioPort
## Working AudioPort implementation (local files) so the real rhythm core can be played.
## Written by B as a starting point for D: D owns this file and may rewrite it freely,
## as long as docs/interfaces.md (AudioPort) keeps holding.
##
## Song files live in res://charts/<song_id>.json (format: docs/rhythm_core.md).
## Song time:
##   - starts at -LEAD_IN (silence), the music starts when time reaches audio.offset
##   - while music plays: system clock, gently pulled toward the audio clock
##     (playback position + time since last mix - output latency), so it never jumps
##   - frozen while paused, continues from the same place on resume

const SONG_FILES := [
	"res://charts/monkey_dancing.json",
	"res://charts/demo_local.json",
]
const LEAD_IN := 1.0              # seconds of silence before song time 0
const SFX_VOICES := 4

var _songs := {}                  # song_id -> full song file Dictionary
var _catalog: Array = []
var _player: AudioStreamPlayer
var _sfx: Array = []
var _sfx_next := 0
var _hit_stream: AudioStreamWAV

var _song_id := ""
var _playing := false
var _paused := false
var _finished := false
var _audio_offset := 0.0
var _audio_started := false
var _duration := 0.0
var _start_usec := 0
var _start_time := 0.0
var _bias := 0.0
var _synced := false
var _frozen_time := 0.0
var _music_volume := 1.0
var _sfx_volume := 1.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_on_music_finished)
	_hit_stream = _make_click()
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.stream = _hit_stream
		add_child(p)
		_sfx.append(p)
	for path in SONG_FILES:
		_load_song_file(path)
	GameSettings.load_settings()
	set_music_volume(GameSettings.music_volume)
	set_sfx_volume(GameSettings.sfx_volume)


# ---- AudioPort -----------------------------------------------------------------------

func get_song_catalog() -> Array:
	return _catalog.duplicate(true)


func load_chart(song_id: String, difficulty: String) -> Dictionary:
	if not _songs.has(song_id):
		return {}
	var song: Dictionary = _songs[song_id]
	var diffs: Dictionary = song.get("difficulties", {})
	var key := difficulty
	if not diffs.has(key) and key == "challenge" and diffs.has("hard"):
		key = "hard"
	if not diffs.has(key):
		return {}
	var chart := {
		"schema_version": int(song.get("schema_version", 2)),
		"song_id": song_id,
		"title": str(song.get("title", song_id)),
		"difficulty": difficulty,
		"duration_sec": float(song.get("duration_sec", 0.0)),
		"notes": (diffs[key] as Array).duplicate(true),
	}
	if song.get("video") is Dictionary:
		chart["video"] = (song["video"] as Dictionary).duplicate(true)
	return chart


func play_song(song_id: String) -> bool:
	if not _songs.has(song_id):
		return false
	stop_music()
	var song: Dictionary = _songs[song_id]
	var audio: Dictionary = song.get("audio", {})
	var stream: AudioStream = null
	var path := str(audio.get("path", ""))
	if path != "" and ResourceLoader.exists(path):
		stream = load(path)
	elif path != "":
		push_warning("Audio not found, playing silently: " + path)
	_player.stream = stream
	_audio_offset = float(audio.get("offset", 0.0))
	_duration = float(song.get("duration_sec", 0.0))
	if stream != null:
		_duration = maxf(_duration, stream.get_length() + _audio_offset)
	_song_id = song_id
	_audio_started = false
	_synced = false
	_bias = 0.0
	_finished = false
	_paused = false
	_start_time = -LEAD_IN
	_start_usec = Time.get_ticks_usec()
	_playing = true
	return true


func stop_music() -> void:
	_playing = false
	_paused = false
	_player.stream_paused = false
	_player.stop()


func pause_music() -> void:
	if not _playing or _paused:
		return
	_frozen_time = get_song_time()
	_paused = true
	_player.stream_paused = true


func resume_music() -> void:
	if not _playing or not _paused:
		return
	_paused = false
	_start_time = _frozen_time
	_start_usec = Time.get_ticks_usec()
	_bias = 0.0
	_synced = false                   # re-sync to the audio clock after it restarts
	_player.stream_paused = false


func get_song_time() -> float:
	if _paused:
		return _frozen_time
	if not _playing:
		return _frozen_time if _finished else 0.0
	return _sys_time() + _bias


func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_player.volume_db = _to_db(_music_volume)


func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	for p in _sfx:
		p.volume_db = _to_db(_sfx_volume)


func play_sfx(sound_id: String) -> void:
	if sound_id != "hit" or _sfx_volume <= 0.0:
		return
	var p: AudioStreamPlayer = _sfx[_sfx_next]   # round robin so fast hits overlap
	_sfx_next = (_sfx_next + 1) % _sfx.size()
	p.play()


# ---- clock ---------------------------------------------------------------------------

func _sys_time() -> float:
	return _start_time + (Time.get_ticks_usec() - _start_usec) / 1000000.0


func _process(_delta: float) -> void:
	if not _playing or _paused:
		return
	var t := get_song_time()
	if _player.stream == null:
		if t >= _duration and _duration > 0.0:
			_end_naturally(t)         # silent chart: finish on its duration
		return
	if not _audio_started:
		if t >= _audio_offset:
			_player.play(maxf(t - _audio_offset, 0.0))
			_audio_started = true
		return
	if not _player.playing:
		return
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


func _on_music_finished() -> void:
	if _playing and not _paused:
		_end_naturally(get_song_time())


func _end_naturally(t: float) -> void:
	if _finished:
		return
	_frozen_time = t
	_playing = false
	_finished = true
	song_finished.emit()


# ---- helpers -------------------------------------------------------------------------

func _load_song_file(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not parsed.has("difficulties"):
		push_error("Could not read song file: " + path)
		return
	var id := str(parsed.get("song_id", path.get_file().get_basename()))
	_songs[id] = parsed
	_catalog.append({"id": id, "title": str(parsed.get("title", id))})


func _to_db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v)


func _make_click() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.04)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := sin(TAU * 1200.0 * i / rate) * (1.0 - float(i) / n) * 0.6
		data.encode_s16(i * 2, int(v * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w
