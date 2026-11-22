extends UIPort
## Functional in-game HUD (1280x720 landscape). Written by B so the round is playable;
## C owns scenes/ui and can restyle or replace it - keep the UIPort calls/signals.
##
## Pause: top-right button, ESC (ui_cancel) or the Android back button.
## The root and labels ignore the mouse so taps reach the playfield underneath.

const W := 1280.0

var _title_label: Label
var _score_label: Label
var _combo_label: Label
var _judge_label: Label
var _pause_button: Button
var _judge_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label = _make_label(Rect2(20, 10, 300, 30), 20, HORIZONTAL_ALIGNMENT_LEFT)
	_title_label.modulate = Color(1, 1, 1, 0.7)
	_title_label.clip_text = true                      # stay left of the MV frame
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_score_label = _make_label(Rect2(20, 36, 300, 56), 44, HORIZONTAL_ALIGNMENT_LEFT)
	_combo_label = _make_label(Rect2(0, 392, W, 56), 42, HORIZONTAL_ALIGNMENT_CENTER)
	_judge_label = _make_label(Rect2(0, 448, W, 140), 52, HORIZONTAL_ALIGNMENT_CENTER)

	_pause_button = Button.new()
	_pause_button.text = "II"
	_pause_button.position = Vector2(W - 96, 16)
	_pause_button.size = Vector2(80, 80)
	_pause_button.add_theme_font_size_override("font_size", 36)
	_pause_button.focus_mode = Control.FOCUS_NONE     # Space/Enter must not trigger it
	_pause_button.pressed.connect(_request_pause)
	add_child(_pause_button)
	set_score(0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if GameState.current_state == GameState.Flow.PLAYING:
			get_viewport().set_input_as_handled()
			_request_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:   # Android back button
		if GameState.current_state == GameState.Flow.PLAYING:
			_request_pause()


func _request_pause() -> void:
	# deferred: the pause overlay sees the same ESC/back event and must not
	# immediately resume a pause that started during this event
	pause_requested.emit.call_deferred()


# ---- UIPort --------------------------------------------------------------------------

func set_song_info(song_id: String, difficulty: String) -> void:
	var title := song_id
	for s in AudioManager.get_song_catalog():
		if str(s.get("id", "")) == song_id:
			title = str(s.get("title", song_id))
	_title_label.text = "%s · %s" % [title, difficulty.capitalize()]
	_combo_label.text = ""
	_judge_label.text = ""


func set_score(value: int) -> void:
	_score_label.text = "%07d" % value


func show_judgement(result: Dictionary) -> void:
	var j := str(result.get("judgement", "NONE"))
	if j == "NONE":
		return
	var combo := int(result.get("combo", 0))
	_combo_label.text = "%d combo" % combo if combo > 1 else ""
	var text := j
	if j != "MISS":
		text += "\n%+d ms" % roundi(float(result.get("delta_sec", 0.0)) * 1000.0)
	var colors := {"PERFECT": Color(1, 0.9, 0.3), "GOOD": Color(0.5, 1, 0.6), "MISS": Color(1, 0.4, 0.4)}
	if _judge_tween and _judge_tween.is_valid():
		_judge_tween.kill()
	_judge_label.text = text
	_judge_label.modulate = colors.get(j, Color.WHITE)
	_judge_tween = create_tween()
	_judge_tween.tween_property(_judge_label, "modulate:a", 0.0, 0.5)


func set_paused(paused: bool) -> void:
	_pause_button.visible = not paused


func _make_label(rect: Rect2, font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l
