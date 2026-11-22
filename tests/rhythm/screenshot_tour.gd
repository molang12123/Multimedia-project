extends Node
## Saves screenshots of menu / gameplay / pause to SHOT_DIR (needs a display, e.g. xvfb-run):
##   SHOT_DIR=/tmp/shots godot --path . res://tests/rhythm/screenshot_tour.tscn
var step := 0
var wall := 0.0
var dir := OS.get_environment("SHOT_DIR")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	(func(): get_tree().current_scene = dummy).call_deferred()
	GameSettings.load_settings()
	GameSettings.note_speed = 1.0

func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("saved ", name)

func _process(delta: float) -> void:
	wall += delta
	match step:
		0:
			if wall > 0.3: GameManager.open_menu(); step = 1; wall = 0.0
		1:
			if wall > 0.6: _shot("1_menu"); GameManager.open_song_select(); step = 2; wall = 0.0
		2:
			if wall > 0.6: _shot("2_song_select"); GameManager.select_song("monkey_dancing", "normal"); step = 3; wall = 0.0
		3:
			if AudioManager.get_song_time() > 7.3: _shot("3_gameplay"); GameManager.pause_game(); step = 4; wall = 0.0
		4:
			if wall > 0.5: _shot("4_pause"); get_tree().quit()
