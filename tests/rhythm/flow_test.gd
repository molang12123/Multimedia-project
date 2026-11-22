extends Node
## End-to-end flow test for B's rhythm core inside A's architecture, with the real
## AudioManager. Runs as a normal scene so autoloads are available:
##   godot --headless --path . res://tests/rhythm/flow_test.tscn
## (MODE=bad makes the bot fail 4 notes on purpose.) Exit code 0 = all checks passed.
## Mouse / pause-button checks only run with a display (normal window or xvfb-run).
##
## Covers: select song -> play with a bot -> ESC pause (time frozen, overlay visible,
## tree paused) -> change note speed + volumes while paused -> ESC resume (time continues)
## -> natural song end -> results -> restart from results -> pause -> restart -> menu.

const SONG := "demo_local"
const DIFF := "challenge"

var failures := 0
var step := "boot"
var mode := OS.get_environment("MODE")
var playfield: Node = null
var overlay: Control = null
var seen := {}
var did := {"tap": 0, "hold": 0, "swipe": 0}
var t_paused := 0.0
var wall := 0.0
var speed_before := 0.0
var runs := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# survive GameManager's scene changes: hand a dummy node to SceneTree as current scene
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	(func(): get_tree().current_scene = dummy).call_deferred()
	GameSettings.load_settings()
	GameSettings.note_speed = 1.0


func check(cond: bool, what: String) -> void:
	print(("PASS: " if cond else "FAIL: ") + what)
	if not cond:
		failures += 1


func _process(delta: float) -> void:
	wall += delta
	match step:
		"boot":
			if wall > 0.3:
				var songs: Array = AudioManager.get_song_catalog()
				check(songs.size() == 2, "catalog has 2 songs")
				GameManager.open_song_select()
				step = "select"
		"select":
			if wall > 0.6:
				GameManager.select_song(SONG, DIFF)
				step = "play1"
		"play1":
			if not _bind():
				return
			_bot()
			var t := AudioManager.get_song_time()
			if t > 6.2:
				_send_escape()
				step = "pausing"
				wall = 0.0
		"pausing":
			if wall > 0.1:
				check(get_tree().paused, "ESC pauses the tree")
				check(GameState.current_state == GameState.Flow.PAUSED, "state PAUSED")
				check(overlay.visible, "pause overlay visible")
				t_paused = AudioManager.get_song_time()
				speed_before = playfield._speed()
				GameSettings.note_speed = 1.5
				overlay._music_slider.value = 0.5
				overlay._sfx_slider.value = 0.3
				step = "paused_wait"
				wall = 0.0
		"paused_wait":
			if wall > 1.5:
				check(absf(AudioManager.get_song_time() - t_paused) < 0.001, "song time frozen while paused")
				_send_escape()
				step = "resuming"
				wall = 0.0
		"resuming":
			if wall > 0.1:
				check(not get_tree().paused and GameState.current_state == GameState.Flow.PLAYING, "ESC resumes")
				var t := AudioManager.get_song_time()
				check(t >= t_paused and t - t_paused < 0.25, "time continues from pause point (%.3f -> %.3f)" % [t_paused, t])
				check(absf(playfield._speed() - speed_before * 1.5) < 0.01, "note speed setting applied")
				check(absf(GameSettings.music_volume - 0.5) < 0.01 and absf(GameSettings.sfx_volume - 0.3) < 0.01, "volume settings stored")
				GameSettings.note_speed = 1.0
				step = "play1b"
		"play1b":
			_bot()
			if GameState.current_state == GameState.Flow.RESULTS:
				var r: Dictionary = GameState.current_result
				print("RESULT ", JSON.stringify(r))
				var expect_miss := 4 if mode == "bad" else 0
				check(int(r.get("total_notes", 0)) == 157, "all 157 notes counted")
				check(int(r.get("miss", -1)) == expect_miss, "miss count %d (expected %d)" % [int(r.get("miss", -1)), expect_miss])
				check(int(r["perfect"]) + int(r["good"]) + int(r["miss"]) == int(r["total_notes"]), "judgements add up")
				step = "restart_from_results"
				wall = 0.0
		"restart_from_results":
			if wall > 0.5:
				playfield = null
				GameManager.restart_game()
				step = "play2"
				wall = 0.0
		"play2":
			if not _bind():
				return
			if AudioManager.get_song_time() > 3.0:
				GameManager.pause_game()
				step = "restart_paused"
				wall = 0.0
		"restart_paused":
			if wall > 0.3:
				GameManager.restart_game()
				step = "after_restart"
				wall = 0.0
		"after_restart":
			if wall > 0.2:
				check(not get_tree().paused and GameState.current_state == GameState.Flow.PLAYING, "restart from pause -> playing")
				check(AudioManager.get_song_time() < 0.5, "restart resets song time (%.2f)" % AudioManager.get_song_time())
				check(playfield._score == 0 and playfield._next_index <= 2, "restart resets notes and score")
				if DisplayServer.get_name() == "headless":
					# simulated mouse needs a display (run with a window or xvfb-run to include it)
					print("SKIP: mouse / pause-button checks (headless)")
					GameManager.pause_game()
					step = "to_menu"
				else:
					_mouse(Vector2(100, 520), true)        # left lane, emulated as touch
					step = "mouse_drag"
				wall = 0.0
		"mouse_drag":
			if wall > 0.05:
				check(playfield._flash[0] > 0.0 and playfield._flash[1] == 0.0, "mouse click on the left lane = left lane press")
				check(playfield._touch.size() == 1, "mouse press tracked as a touch")
				var drag := InputEventMouseMotion.new()
				drag.position = Vector2(100, 460)
				drag.relative = Vector2(0, -60)
				drag.button_mask = MOUSE_BUTTON_MASK_LEFT
				Input.parse_input_event(drag)
				step = "mouse_up"
				wall = 0.0
		"mouse_up":
			if wall > 0.05:
				check(playfield._touch.size() == 1 and playfield._touch.values()[0]["swiped"], "mouse drag up 60px registers as a swipe")
				_mouse(Vector2(100, 460), false)
				step = "click_pause"
				wall = 0.0
		"click_pause":
			if wall > 0.05:
				playfield._flash[1] = 0.0
				_mouse(Vector2(1224, 56), true)
				_mouse(Vector2(1224, 56), false)
				step = "check_click_pause"
				wall = 0.0
		"check_click_pause":
			if wall > 0.2:
				check(GameState.current_state == GameState.Flow.PAUSED, "clicking the pause button pauses")
				check(playfield._flash[1] == 0.0, "pause button click is not a right-lane hit")
				step = "to_menu"
				wall = 0.0
		"to_menu":
			if wall > 0.3:
				overlay.menu_requested.emit()
				step = "check_menu"
				wall = 0.0
		"check_menu":
			if wall > 0.5:
				check(GameState.current_state == GameState.Flow.MENU and not get_tree().paused, "menu from pause")
				print("Flow test complete. Failures: ", failures)
				get_tree().quit(1 if failures > 0 else 0)
				step = "done"


func _bind() -> bool:
	if playfield != null and is_instance_valid(playfield):
		return true
	var scene := get_tree().current_scene
	if scene == null or not scene.has_node("RhythmPlayfield"):
		return false
	playfield = scene.get_node("RhythmPlayfield")
	overlay = scene.get_node("PauseOverlay")
	seen.clear()
	return true


func _mouse(pos: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	ev.pressed = down
	Input.parse_input_event(ev)


func _send_escape() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


## Plays like a player who is 10 ms late; in MODE=bad fails one of each kind + one swipe lift.
func _bot() -> void:
	if playfield == null or get_tree().paused:
		return
	var t := AudioManager.get_song_time()
	for n in playfield._active.duplicate():
		if not is_instance_valid(n) or n.missed:
			continue
		var id: int = n.get_instance_id()
		var fid: int = 10 + n.lane
		if t < n.hit_time + 0.01:
			continue
		match n.kind:
			"tap":
				if seen.has(id):
					continue
				seen[id] = true
				if mode == "bad" and did["tap"] == 0:
					did["tap"] = 1
					continue
				playfield._press(fid, n.lane, t)
				playfield._release(fid, t)
			"hold":
				if not n.holding and not seen.has(id):
					seen[id] = true
					playfield._press(fid, n.lane, t)
				elif n.holding:
					var early: bool = mode == "bad" and did["hold"] == 0
					if t >= n.tail_time() - (0.45 if early else 0.02):
						if early:
							did["hold"] = 1
						playfield._release(fid, t)
			"swipe":
				if not n.swipe_pending and not seen.has(id):
					seen[id] = true
					playfield._press(fid, n.lane, t)
				elif n.swipe_pending:
					if mode == "bad" and did["swipe"] == 0:
						did["swipe"] = 1
						playfield._swipe(fid, "down" if n.swipe_dir == "up" else "up")
					elif mode == "bad" and did["swipe"] == 1:
						did["swipe"] = 2
						playfield._release(fid, t)
					else:
						playfield._swipe(fid, n.swipe_dir)
