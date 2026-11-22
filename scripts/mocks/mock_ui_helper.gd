class_name MockUIHelper
extends RefCounted
## A-owned utility for temporary interfaces only.

static func make_page(root: Control, title: String) -> VBoxContainer:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	root.add_child(bg)
	bg.color = Color(0.09, 0.14, 0.22)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	add_label(column, title, 48)
	return column


static func add_label(column: VBoxContainer, content: String, font_size: int = 32) -> Label:
	var label := Label.new()
	label.text = content
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(480, 55)
	label.add_theme_font_size_override("font_size", font_size)
	column.add_child(label)
	return label


static func add_button(column: VBoxContainer, title: String) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(480, 68)
	button.add_theme_font_size_override("font_size", 31)
	column.add_child(button)
	return button
