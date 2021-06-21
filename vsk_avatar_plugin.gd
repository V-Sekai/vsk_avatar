@tool
extends EditorPlugin

const avatar_definition_editor_const = preload("vsk_avatar_definition_editor.gd")
const avatar_definition_const = preload("vsk_avatar_definition.gd")

var editor_interface : EditorInterface = null
var avatar_definition_editor : Control = null


func _init():
	print("Initialising VSKAvatar plugin")


func _notification(p_notification: int):
	match p_notification:
		NOTIFICATION_PREDELETE:
			print("Destroying VSKAvatar plugin")


func get_name() -> String:
	return "VSKAvatar"

func _enter_tree() -> void:
	editor_interface = get_editor_interface()
	avatar_definition_editor = avatar_definition_editor_const.new(self)
	
	editor_interface.get_editor_viewport().add_child(avatar_definition_editor)
	
	avatar_definition_editor.options.hide()

func _exit_tree() -> void:
	avatar_definition_editor.queue_free()

func edit(p_object : Object) -> void:
	if p_object is Node and p_object.get_script() == avatar_definition_const:
		avatar_definition_editor.edit(p_object)

func handles(p_object : Object) -> bool:
	if p_object.get_script() == avatar_definition_const:
		return true
	else:
		return false

func make_visible(p_visible : bool) -> void:
	if (p_visible):
		if avatar_definition_editor:
			if avatar_definition_editor.options:
				avatar_definition_editor.options.show()
	else:
		if avatar_definition_editor:
			if avatar_definition_editor.options:
				avatar_definition_editor.options.hide()
			avatar_definition_editor.edit(null)
