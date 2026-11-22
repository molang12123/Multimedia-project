extends Control
## A-owned single-round integration. B/C/D may replace child scenes without
## changing the public calls below.

@onready var rhythm: RhythmPort = $RhythmPlayfield
@onready var hud: UIPort = $RhythmHUD
@onready var pause_overlay: UIPort = $PauseOverlay


func _ready() -> void:
	GameManager.attach_controller(self)
	rhythm.score_changed.connect(hud.set_score)
	rhythm.note_judged.connect(hud.show_judgement)
	rhythm.rhythm_finished.connect(_on_rhythm_finished)
	AudioManager.song_finished.connect(_on_song_finished)
	hud.pause_requested.connect(GameManager.pause_game)
	if hud.has_signal("tap_requested"):
		hud.tap_requested.connect(_on_mock_tap)
	pause_overlay.resume_requested.connect(GameManager.resume_game)
	pause_overlay.restart_requested.connect(GameManager.restart_game)
	pause_overlay.menu_requested.connect(GameManager.open_menu)
	call_deferred("_start_round")


func _exit_tree() -> void:
	GameManager.detach_controller(self)
	if AudioManager.song_finished.is_connected(_on_song_finished):
		AudioManager.song_finished.disconnect(_on_song_finished)


func _start_round() -> void:
	rhythm.reset_rhythm()
	hud.set_song_info(GameState.current_song_id, GameState.current_difficulty)
	hud.set_score(0)
	pause_overlay.set_paused(false)
	var chart: Dictionary = AudioManager.load_chart(GameState.current_song_id, GameState.current_difficulty)
	if chart.is_empty() or not rhythm.start_rhythm(chart):
		push_error("Could not start rhythm chart")
		GameManager.open_menu()
		return
	if not AudioManager.play_song(GameState.current_song_id):
		push_error("Could not start audio")
		GameManager.open_menu()


func pause_round() -> void:
	rhythm.pause_rhythm()
	pause_overlay.set_paused(true)


func resume_round() -> void:
	rhythm.resume_rhythm()
	pause_overlay.set_paused(false)


func restart_round() -> void:
	AudioManager.stop_music()
	_start_round()


func _on_mock_tap() -> void:
	rhythm.try_hit(AudioManager.get_song_time())


func _on_song_finished() -> void:
	if GameState.current_state == GameState.Flow.PLAYING:
		rhythm.finalize_rhythm()


func _on_rhythm_finished(result: Dictionary) -> void:
	GameManager.finish_game(result)
