extends AudioPort
## A-only stand-in for D's audio and chart system. No audio files required.

const MOCK_SONGS := [
	{"id": "song_01", "title": "Mock Song 01"},
	{"id": "song_02", "title": "Mock Song 02"},
	{"id": "song_03", "title": "Mock Song 03"}
]

var _elapsed := 0.0
var _duration := 15.0
var _playing := false
var _paused := false
var _finished := false
var _music_volume := 1.0
var _sfx_volume := 1.0


func _process(delta: float) -> void:
	if not _playing or _paused:
		return
	_elapsed = minf(_elapsed + delta, _duration)
	if _elapsed >= _duration and not _finished:
		_playing = false
		_finished = true
		song_finished.emit()


func play_song(song_id: String) -> bool:
	var valid := false
	for entry in MOCK_SONGS:
		if entry["id"] == song_id:
			valid = true
	if not valid:
		return false
	_elapsed = 0.0
	_duration = 15.0
	_paused = false
	_finished = false
	_playing = true
	return true


func stop_music() -> void:
	_playing = false
	_paused = false


func pause_music() -> void:
	_paused = true


func resume_music() -> void:
	if _playing:
		_paused = false


func get_song_time() -> float:
	return _elapsed


func get_song_catalog() -> Array:
	return MOCK_SONGS.duplicate(true)


func load_chart(song_id: String, difficulty: String) -> Dictionary:
	if difficulty not in ["easy", "normal", "challenge"]:
		return {}
	var found := false
	for entry in MOCK_SONGS:
		if entry["id"] == song_id:
			found = true
	if not found:
		return {}
	var notes: Array = []
	var step := 1.6 if difficulty == "easy" else (1.2 if difficulty == "normal" else 0.9)
	var t := 2.0
	while t <= 12.5:
		notes.append({"time_sec": t})
		t += step
	return {
		"schema_version": 1,
		"song_id": song_id,
		"difficulty": difficulty,
		"duration_sec": 15.0,
		"notes": notes
	}


func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)


func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)


func play_sfx(_sound_id: String) -> void:
	pass
