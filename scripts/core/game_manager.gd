extends Node
## A-owned navigation coordinator. Only this node changes game scenes/states.

const MENU_SCENE := "res://scenes/mocks/mock_main_menu.tscn"
const SONG_SCENE := "res://scenes/mocks/mock_song_select.tscn"
const GAME_SCENE := "res://scenes/core/rhythm_game.tscn"
const RESULTS_SCENE := "res://scenes/mocks/mock_results_screen.tscn"
const SIMPLE_SCENE := "res://scenes/mocks/mock_simple_screen.tscn"

var _changing_scene := false
var _controller: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(_on_scene_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and GameState.current_state == GameState.Flow.PLAYING:
		pause_game()


func attach_controller(controller: Node) -> void:
	_controller = controller


func detach_controller(controller: Node) -> void:
	if _controller == controller:
		_controller = null


func _connect_if_present(scene: Node, event: StringName, handler: Callable) -> void:
	if scene.has_signal(event) and not scene.is_connected(event, handler):
		scene.connect(event, handler)


func _on_scene_changed(scene: Node) -> void:
	_changing_scene = false
	if scene == null:
		return
	_connect_if_present(scene, &"start_pressed", Callable(self, "open_song_select"))
	_connect_if_present(scene, &"song_selected", Callable(self, "select_song"))
	_connect_if_present(scene, &"restart_requested", Callable(self, "restart_game"))
	_connect_if_present(scene, &"menu_requested", Callable(self, "open_menu"))
	_connect_if_present(scene, &"song_select_requested", Callable(self, "open_song_select"))
	_connect_if_present(scene, &"tutorial_requested", Callable(self, "open_tutorial"))
	_connect_if_present(scene, &"settings_requested", Callable(self, "open_settings"))
	_connect_if_present(scene, &"free_play_requested", Callable(self, "open_free_play"))


func _switch_to(next_state: int, path: String, allow_same: bool = false) -> bool:
	if _changing_scene:
		return false
	if next_state == GameState.current_state:
		if not allow_same:
			return false
	elif not GameState.can_transition(next_state):
		return false
	_changing_scene = true
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		_changing_scene = false
		push_error("Scene change failed: %s (%s)" % [path, err])
		return false
	if next_state != GameState.current_state:
		GameState.transition_to(next_state)
	return true


func open_menu() -> void:
	if _changing_scene:
		return
	AudioManager.stop_music()
	get_tree().paused = false
	if _switch_to(GameState.Flow.MENU, MENU_SCENE, true):
		GameState.clear_run(true)


func open_song_select() -> void:
	if _changing_scene:
		return
	if GameState.current_state == GameState.Flow.RESULTS:
		GameState.clear_run()
	_switch_to(GameState.Flow.SONG_SELECT, SONG_SCENE)


func select_song(song_id: String, difficulty: String) -> void:
	if _changing_scene or not GameState.select_song(song_id, difficulty):
		return
	start_game()


func start_game() -> void:
	if _changing_scene or GameState.current_state != GameState.Flow.SONG_SELECT:
		return
	if GameState.current_song_id.is_empty():
		return
	AudioManager.stop_music()
	if _switch_to(GameState.Flow.PLAYING, GAME_SCENE):
		GameState.clear_run()


func pause_game() -> void:
	if _changing_scene or GameState.current_state != GameState.Flow.PLAYING or not is_instance_valid(_controller):
		return
	AudioManager.pause_music()
	_controller.pause_round()
	if GameState.transition_to(GameState.Flow.PAUSED):
		get_tree().paused = true


func resume_game() -> void:
	if _changing_scene or GameState.current_state != GameState.Flow.PAUSED or not is_instance_valid(_controller):
		return
	if GameState.transition_to(GameState.Flow.PLAYING):
		_controller.resume_round()
		AudioManager.resume_music()
		get_tree().paused = false


func restart_game() -> void:
	if _changing_scene or GameState.current_state not in [
		GameState.Flow.PLAYING, GameState.Flow.PAUSED, GameState.Flow.RESULTS
	]:
		return
	get_tree().paused = false
	AudioManager.stop_music()
	GameState.clear_run()
	if GameState.current_state == GameState.Flow.RESULTS:
		_switch_to(GameState.Flow.PLAYING, GAME_SCENE)
		return
	if GameState.current_state == GameState.Flow.PAUSED:
		GameState.transition_to(GameState.Flow.PLAYING)
	if is_instance_valid(_controller):
		_controller.restart_round()
	else:
		_switch_to(GameState.Flow.PLAYING, GAME_SCENE, true)


func finish_game(result: Dictionary) -> void:
	if _changing_scene or GameState.current_state != GameState.Flow.PLAYING:
		return
	AudioManager.stop_music()
	if _switch_to(GameState.Flow.RESULTS, RESULTS_SCENE):
		GameState.set_result(result)


func open_tutorial() -> void:
	_switch_to(GameState.Flow.TUTORIAL, SIMPLE_SCENE)


func open_settings() -> void:
	_switch_to(GameState.Flow.SETTINGS, SIMPLE_SCENE)


func open_free_play() -> void:
	_switch_to(GameState.Flow.FREE_PLAY, SIMPLE_SCENE)
