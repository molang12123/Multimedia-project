extends CanvasLayer
## Minimal stand-in for C's UI. The manager only talks to it through the
## signals and set_* / show_* methods below, so it can be swapped out later.

signal difficulty_selected(difficulty: String)
signal song_selected(index: int)

var _titles: Array = []
var _song_index := 0
var _score_label: Label
var _combo_label: Label
var _judge_label: Label
var _fps_label: Label
var _notice_label: Label
var _menu: Control
var _result_label: Label
var _song_button: Button
var _judge_tween: Tween


func _ready() -> void:
	_score_label = _make_label(Vector2(0, 30), 56, HORIZONTAL_ALIGNMENT_CENTER)
	_combo_label = _make_label(Vector2(0, 110), 44, HORIZONTAL_ALIGNMENT_CENTER)
	_judge_label = _make_label(Vector2(0, 700), 64, HORIZONTAL_ALIGNMENT_CENTER)
	_judge_label.size.y = 200
	_fps_label = _make_label(Vector2(20, 1230), 28, HORIZONTAL_ALIGNMENT_LEFT)
	_fps_label.modulate = Color(1, 1, 1, 0.6)
	_notice_label = _make_label(Vector2(0, 1180), 26, HORIZONTAL_ALIGNMENT_CENTER)
	_notice_label.modulate = Color(1, 0.8, 0.4)

	_menu = Control.new()
	add_child(_menu)
	_result_label = _make_label(Vector2(0, 260), 40, HORIZONTAL_ALIGNMENT_CENTER, _menu)
	_result_label.size.y = 300
	_song_button = Button.new()
	_song_button.position = Vector2(60, 580)
	_song_button.size = Vector2(600, 90)
	_song_button.add_theme_font_size_override("font_size", 32)
	_song_button.pressed.connect(_on_song_pressed)
	_menu.add_child(_song_button)
	var y := 400.0
	for d in ["easy", "normal", "hard"]:
		var b := Button.new()
		b.text = d.capitalize()
		b.position = Vector2(426, y)
		b.size = Vector2(300, 65)
		b.add_theme_font_size_override("font_size", 44)
		b.pressed.connect(func(): difficulty_selected.emit(d))
		_menu.add_child(b)
		y += 75.0
	set_score(0)
	set_combo(0)


func _process(_delta: float) -> void:
	_fps_label.text = "FPS %d" % Engine.get_frames_per_second()


func set_songs(titles: Array) -> void:
	_titles = titles
	_song_index = 0
	_refresh_song_button()


func show_menu(result_text: String = "") -> void:
	_result_label.text = result_text if result_text != "" else "Pick a song and a difficulty"
	_menu.visible = true


func hide_menu() -> void:
	_menu.visible = false
	_judge_label.text = ""


func set_notice(text: String) -> void:
	_notice_label.text = text


func set_score(value: int) -> void:
	_score_label.text = "%07d" % value


func set_combo(value: int) -> void:
	_combo_label.text = "%d combo" % value if value > 1 else ""


func flash_judgement(text: String, color: Color) -> void:
	# 如果上一個漸隱動畫還沒跑完，就先強制停止，避免干擾新的判定字
	if _judge_tween and _judge_tween.is_valid():
		_judge_tween.kill()
			
	_judge_label.text = text
	_judge_label.modulate = color
		
		# 建立新的漸隱動畫並記錄下來
	_judge_tween = create_tween()
	_judge_tween.tween_property(_judge_label, "modulate:a", 0.0, 0.5)


func _on_song_pressed() -> void:
	if _titles.is_empty():
		return
	_song_index = (_song_index + 1) % _titles.size()
	_refresh_song_button()
	song_selected.emit(_song_index)


func _refresh_song_button() -> void:
	_song_button.text = "Song: %s  (tap to change)" % (_titles[_song_index] if not _titles.is_empty() else "-")


func _make_label(pos: Vector2, font_size: int, align: HorizontalAlignment, parent: Node = self) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(720, font_size * 1.5)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l
