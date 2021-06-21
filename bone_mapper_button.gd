@tool
extends HBoxContainer

var select_bone_button: Button = null
var clear_bone_button: Button = null

func _init():
	select_bone_button = Button.new()
	add_child(select_bone_button)
	select_bone_button.rect_size = Vector2()
	select_bone_button.size_flags_horizontal = SIZE_EXPAND_FILL
	
	clear_bone_button = Button.new()
	clear_bone_button.rect_size = Vector2()
	add_child(clear_bone_button)

