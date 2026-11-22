extends UIPort
## A-only temporary HUD; can be swapped for C's rhythm_hud.tscn.

var _title_label: Label
var _score_label: Label
var _judgement_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	add_child(column)
	column.position = Vector2(26, 18)
	column.add_theme_constant_override("separation", 8)
	_title_label = MockUIHelper.add_label(column, "Mock Song", 24)
	_score_label = MockUIHelper.add_label(column, "分数：0", 38)
	_judgement_label = MockUIHelper.add_label(column, "等待判定", 24)
	MockUIHelper.add_button(column, "模拟点击").pressed.connect(func(): tap_requested.emit())
	MockUIHelper.add_button(column, "暂停").pressed.connect(func(): pause_requested.emit())


func set_song_info(song_id: String, difficulty: String) -> void:
	_title_label.text = "%s · %s" % [song_id, difficulty]


func set_score(value: int) -> void:
	_score_label.text = "分数：%d" % value


func show_judgement(result: Dictionary) -> void:
	_judgement_label.text = "判定：%s" % str(result.get("judgement", "NONE"))
