extends UIPort
## A-only temporary main menu.

func _ready() -> void:
	# Explicit UI registration makes navigation independent of scene_changed timing.
	GameManager.bind_screen(self)
	var column := MockUIHelper.make_page(self, "银龄节奏 · A 组 Mock")
	MockUIHelper.add_label(column, "核心流程演示（尚未接入正式模块）", 24)
	MockUIHelper.add_button(column, "开始游戏").pressed.connect(func(): start_pressed.emit())
	MockUIHelper.add_button(column, "新手教学（占位）").pressed.connect(func(): tutorial_requested.emit())
	MockUIHelper.add_button(column, "设置（占位）").pressed.connect(func(): settings_requested.emit())
	MockUIHelper.add_button(column, "自由演奏（占位）").pressed.connect(func(): free_play_requested.emit())
