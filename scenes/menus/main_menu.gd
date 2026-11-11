extends Control

func _ready() -> void:
	$CenterContainer/VBoxContainer/Button.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
