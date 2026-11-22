extends UIPort
## A-only stand-in for C's song/difficulty selection.

var _songs: Array = []
var _song_choice: OptionButton
var _difficulty_choice: OptionButton


func _ready() -> void:
	var column := MockUIHelper.make_page(self, "选择歌曲与难度")
	_songs = AudioManager.get_song_catalog()
	_song_choice = OptionButton.new()
	_song_choice.custom_minimum_size = Vector2(480, 65)
	for song in _songs:
		_song_choice.add_item(str(song.get("title", song.get("id", ""))))
	column.add_child(_song_choice)
	_difficulty_choice = OptionButton.new()
	_difficulty_choice.custom_minimum_size = Vector2(480, 65)
	for d in ["easy", "normal", "challenge"]:
		_difficulty_choice.add_item(d)
	column.add_child(_difficulty_choice)
	MockUIHelper.add_button(column, "开始").pressed.connect(_on_start)
	MockUIHelper.add_button(column, "返回主菜单").pressed.connect(func(): menu_requested.emit())


func _on_start() -> void:
	if _songs.is_empty():
		return
	var index := _song_choice.selected
	if index < 0 or index >= _songs.size():
		return
	var difficulties := ["easy", "normal", "challenge"]
	song_selected.emit(str(_songs[index]["id"]), difficulties[_difficulty_choice.selected])
