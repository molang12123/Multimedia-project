extends Node
## A-owned source of truth for navigation, selection and the last result.

signal state_changed(previous: int, current: int)
signal selection_changed(song_id: String, difficulty: String)
signal result_changed(result: Dictionary)

enum Flow { MENU, SONG_SELECT, PLAYING, PAUSED, RESULTS, TUTORIAL, SETTINGS, FREE_PLAY }

const VALID_DIFFICULTIES := ["easy", "normal", "challenge"]
const ALLOWED := {
	Flow.MENU: [Flow.SONG_SELECT, Flow.TUTORIAL, Flow.SETTINGS, Flow.FREE_PLAY],
	Flow.SONG_SELECT: [Flow.MENU, Flow.PLAYING],
	Flow.PLAYING: [Flow.PAUSED, Flow.RESULTS, Flow.MENU],
	Flow.PAUSED: [Flow.PLAYING, Flow.MENU],
	Flow.RESULTS: [Flow.PLAYING, Flow.SONG_SELECT, Flow.MENU],
	Flow.TUTORIAL: [Flow.MENU],
	Flow.SETTINGS: [Flow.MENU],
	Flow.FREE_PLAY: [Flow.MENU]
}

var current_song_id: String = ""
var current_difficulty: String = "easy"
var current_state: int = Flow.MENU
var current_result: Dictionary = {}
var return_scene: String = ""

var is_paused: bool:
	get:
		return current_state == Flow.PAUSED


func can_transition(next_state: int) -> bool:
	return next_state != current_state and ALLOWED.get(current_state, []).has(next_state)


func transition_to(next_state: int) -> bool:
	if not can_transition(next_state):
		return false
	var previous: int = current_state
	current_state = next_state
	state_changed.emit(previous, current_state)
	return true


func select_song(song_id: String, difficulty: String) -> bool:
	if current_state != Flow.SONG_SELECT or song_id.is_empty() or not VALID_DIFFICULTIES.has(difficulty):
		return false
	current_song_id = song_id
	current_difficulty = difficulty
	selection_changed.emit(song_id, difficulty)
	return true


func set_result(result: Dictionary) -> void:
	current_result = result.duplicate(true)
	result_changed.emit(current_result.duplicate(true))


func clear_run(clear_selection: bool = false) -> void:
	set_result({})
	if clear_selection:
		current_song_id = ""
		current_difficulty = "easy"
		selection_changed.emit(current_song_id, current_difficulty)
