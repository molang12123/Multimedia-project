extends UIPort
## Functional pause overlay (1280x720 landscape). Written by B so pausing works end to end;
## C owns scenes/ui and can restyle or replace it - keep the UIPort calls/signals.
##
## Must run while the tree is paused (Process Mode = Always).
## Buttons: resume / restart / back to menu (signals handled by A's GameManager).
## Sliders: music volume, hit sound volume, note speed -> GameSettings (user://settings.cfg).
## Volumes apply immediately through AudioManager; note speed applies on resume.

const W := 1280.0
const H := 720.0

var _music_slider: HSlider
var _sfx_slider: HSlider
var _speed_slider: HSlider
var _music_value: Label
var _sfx_value: Label
var _speed_value: Label
var _resume_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameSettings.load_settings()

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)                    # also blocks taps from reaching the game

	var title := Label.new()
	title.text = "暫停"
	title.position = Vector2(0, 60)
	title.size = Vector2(W, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	add_child(title)

	# left column: actions
	var actions := VBoxContainer.new()
	actions.position = Vector2(180, 200)
	actions.size = Vector2(380, 400)
	actions.add_theme_constant_override("separation", 22)
	add_child(actions)
	_resume_button = _add_button(actions, "繼續")
	_resume_button.pressed.connect(_request_resume)
	_add_button(actions, "重新開始").pressed.connect(func(): restart_requested.emit())
	_add_button(actions, "返回主選單").pressed.connect(func(): menu_requested.emit())

	# right column: settings
	var settings := VBoxContainer.new()
	settings.position = Vector2(660, 200)
	settings.size = Vector2(460, 400)
	settings.add_theme_constant_override("separation", 14)
	add_child(settings)
	var row := _add_slider(settings, "音樂音量", 0.0, 1.0, 0.05)
	_music_slider = row[0]
	_music_value = row[1]
	row = _add_slider(settings, "打擊音效音量", 0.0, 1.0, 0.05)
	_sfx_slider = row[0]
	_sfx_value = row[1]
	row = _add_slider(settings, "音符速度", GameSettings.SPEED_MIN, GameSettings.SPEED_MAX, 0.1)
	_speed_slider = row[0]
	_speed_value = row[1]
	_refresh()
	_music_slider.value_changed.connect(_on_music)
	_sfx_slider.value_changed.connect(_on_sfx)
	_speed_slider.value_changed.connect(_on_speed)
	visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_request_resume()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible:   # Android back button
		_request_resume()


func _request_resume() -> void:
	# deferred so the HUD, which sees the same ESC/back event, cannot re-pause at once
	resume_requested.emit.call_deferred()


# ---- UIPort --------------------------------------------------------------------------

func set_paused(paused: bool) -> void:
	if paused:
		_refresh()
	elif visible:
		GameSettings.save_settings()
	visible = paused


# ---- settings ------------------------------------------------------------------------

func _refresh() -> void:
	_music_slider.set_value_no_signal(GameSettings.music_volume)
	_sfx_slider.set_value_no_signal(GameSettings.sfx_volume)
	_speed_slider.set_value_no_signal(GameSettings.note_speed)
	_update_labels()


func _update_labels() -> void:
	_music_value.text = "%d%%" % roundi(GameSettings.music_volume * 100.0)
	_sfx_value.text = "%d%%" % roundi(GameSettings.sfx_volume * 100.0)
	_speed_value.text = "%.1fx" % GameSettings.note_speed


func _on_music(v: float) -> void:
	GameSettings.music_volume = v
	AudioManager.set_music_volume(v)
	_update_labels()


func _on_sfx(v: float) -> void:
	GameSettings.sfx_volume = v
	AudioManager.set_sfx_volume(v)
	AudioManager.play_sfx("hit")      # preview the new volume
	_update_labels()


func _on_speed(v: float) -> void:
	GameSettings.note_speed = v
	_update_labels()


# ---- widgets -------------------------------------------------------------------------

func _add_button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 84)
	b.add_theme_font_size_override("font_size", 34)
	parent.add_child(b)
	return b


func _add_slider(parent: Control, text: String, lo: float, hi: float, step: float) -> Array:
	var head := HBoxContainer.new()
	parent.add_child(head)
	var name_label := Label.new()
	name_label.text = text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 28)
	head.add_child(name_label)
	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 28)
	head.add_child(value_label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(460, 48)   # big enough for a thumb
	parent.add_child(s)
	return [s, value_label]
