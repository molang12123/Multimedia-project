extends UIPort
## This overlay must keep processing input while SceneTree.paused is true.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := MockUIHelper.make_page(self, "游戏已暂停")
	var background: ColorRect = get_child(0)
	background.color = Color(0.025, 0.04, 0.07, 0.92)
	MockUIHelper.add_button(column, "继续").pressed.connect(func(): resume_requested.emit())
	MockUIHelper.add_button(column, "重新开始").pressed.connect(func(): restart_requested.emit())
	MockUIHelper.add_button(column, "返回主菜单").pressed.connect(func(): menu_requested.emit())
	visible = false


func set_paused(value: bool) -> void:
	visible = value
