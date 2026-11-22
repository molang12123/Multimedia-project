extends UIPort
## A-only temporary results scene.

func _ready() -> void:
	# Explicit UI registration makes navigation independent of scene_changed timing.
	GameManager.bind_screen(self)
	var column := MockUIHelper.make_page(self, "本局结算")
	var r: Dictionary = GameState.current_result
	MockUIHelper.add_label(column, "%s / %s" % [
		str(r.get("song_id", "")), str(r.get("difficulty", ""))], 28)
	MockUIHelper.add_label(column, "分数：%d" % int(r.get("score", 0)), 38)
	MockUIHelper.add_label(column, "Perfect %d  Good %d  Miss %d" % [
		int(r.get("perfect", 0)), int(r.get("good", 0)), int(r.get("miss", 0))], 25)
	MockUIHelper.add_button(column, "重新开始").pressed.connect(func(): restart_requested.emit())
	MockUIHelper.add_button(column, "重新选歌").pressed.connect(func(): song_select_requested.emit())
	MockUIHelper.add_button(column, "返回主菜单").pressed.connect(func(): menu_requested.emit())
