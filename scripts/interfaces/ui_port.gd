class_name UIPort
extends Control
## Each C-owned screen only needs to emit signals and implement the methods it uses.
signal start_pressed()
signal song_selected(song_id: String, difficulty: String)
signal pause_requested()
signal resume_requested()
signal restart_requested()
signal menu_requested()
signal song_select_requested()
signal tutorial_requested()
signal settings_requested()
signal free_play_requested()
## Optional convenience signal used by the A-owned mock HUD.
signal tap_requested()

func set_song_info(_song_id: String, _difficulty: String) -> void:
	pass

func set_score(_value: int) -> void:
	pass

func show_judgement(_result: Dictionary) -> void:
	pass

func set_paused(_paused: bool) -> void:
	pass

func set_result(_result: Dictionary) -> void:
	pass
