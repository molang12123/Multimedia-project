extends SceneTree
## Run from project root:
## godot --headless --path . --script res://tests/core/core_state_test.gd

const StateScript = preload("res://scripts/core/game_state.gd")
const RhythmScript = preload("res://scripts/mocks/mock_rhythm_manager.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _check(condition: bool, detail: String) -> void:
	if condition:
		print("PASS: ", detail)
	else:
		failures += 1
		push_error("FAIL: " + detail)


func _run_tests() -> void:
	var state: Node = StateScript.new()
	root.add_child(state)
	_check(state.current_state == state.Flow.MENU, "initial MENU")
	_check(not state.transition_to(state.Flow.RESULTS), "reject illegal MENU -> RESULTS")
	_check(state.transition_to(state.Flow.SONG_SELECT), "open song select")
	_check(not state.select_song("song_01", "invalid"), "reject bad difficulty")
	_check(state.select_song("song_01", "easy"), "save song & difficulty")
	_check(state.current_song_id == "song_01" and state.current_difficulty == "easy", "selection persists")
	_check(state.transition_to(state.Flow.PLAYING), "begin round")
	_check(not state.transition_to(state.Flow.SONG_SELECT), "reject PLAYING -> SONG_SELECT")
	_check(state.transition_to(state.Flow.PAUSED) and state.is_paused, "pause once")
	_check(not state.transition_to(state.Flow.PAUSED), "reject double pause")
	_check(state.transition_to(state.Flow.PLAYING) and not state.is_paused, "resume")
	state.set_result({"score": 100})
	_check(state.current_result["score"] == 100, "result stored")
	state.clear_run(true)
	_check(state.current_result.is_empty() and state.current_song_id.is_empty(), "clear run")

	var mock: Node2D = RhythmScript.new()
	root.add_child(mock)
	var fired := {"count": 0}
	mock.rhythm_finished.connect(func(_result): fired["count"] += 1)
	_check(mock.start_rhythm({
		"song_id": "song_01", "difficulty": "easy",
		"notes": [{"time_sec": 2.0}, {"time_sec": 3.0}]
	}), "mock rhythm starts")
	_check(mock.try_hit(2.0).get("judgement", "") == "PERFECT", "mock try_hit")
	mock.finalize_rhythm()
	mock.finalize_rhythm()
	_check(fired["count"] == 1, "finished once only")
	mock.reset_rhythm()
	_check(not mock._running and mock._score == 0, "reset clears score")
	print("Core tests complete. Failures: ", failures)
	quit(1 if failures > 0 else 0)
