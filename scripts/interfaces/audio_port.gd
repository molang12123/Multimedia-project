class_name AudioPort
extends Node
## Interface contract for D's AudioManager and A's MockAudioManager.
signal song_finished()

func play_song(_song_id: String) -> bool:
	return false

func stop_music() -> void:
	pass

func pause_music() -> void:
	pass

func resume_music() -> void:
	pass

func get_song_time() -> float:
	return 0.0

func load_chart(_song_id: String, _difficulty: String) -> Dictionary:
	return {}

func get_song_catalog() -> Array:
	return []

func set_music_volume(_value: float) -> void:
	pass

func set_sfx_volume(_value: float) -> void:
	pass

func play_sfx(_sound_id: String) -> void:
	pass
