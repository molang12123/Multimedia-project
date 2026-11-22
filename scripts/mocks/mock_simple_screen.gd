extends UIPort
## A-only placeholders for C's tutorial/settings/free-play screens.

func _ready() -> void:
	# Explicit UI registration makes navigation independent of scene_changed timing.
	GameManager.bind_screen(self)
	var title := "功能占位"
	if GameState.current_state == GameState.Flow.TUTORIAL:
		title = "新手教学（Mock）"
	elif GameState.current_state == GameState.Flow.SETTINGS:
		title = "设置（Mock）"
	elif GameState.current_state == GameState.Flow.FREE_PLAY:
		title = "自由演奏（Mock）
	var column := MockUIHelper.make_page(self, title)
	MockUIHelper.add_label(column, "由 C/D 开发正式画面，A 不实现内部功能。", 23)
	MockUIHelper.add_button(column, "返回主菜单").pressed.connect(func(): menu_requested.emit())
