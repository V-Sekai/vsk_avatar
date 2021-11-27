@tool
extends EditorPlugin

const avatar_definition_const = preload("vsk_avatar_definition.gd")

var editor_interface : EditorInterface = null
var avatar_definition_editor : Control = null


func _init():
	print("Initialising VSKAvatar plugin")


func _notification(p_notification: int):
	match p_notification:
		NOTIFICATION_PREDELETE:
			print("Destroying VSKAvatar plugin")


func _get_plugin_name() -> String:
	return "VSKAvatar"

func _enter_tree() -> void:
	editor_interface = get_editor_interface()
	editor_interface.get_viewport().call_deferred("add_child", avatar_definition_editor)
	
	avatar_definition_editor.options.hide()

func _exit_tree() -> void:
	avatar_definition_editor.queue_free()

func _edit(p_object : Object) -> void:
	if p_object is Node and typeof(p_object.get("skeleton_path")) == TYPE_NODE_PATH:
		avatar_definition_editor.edit(p_object)

func _handles(p_object : Object) -> bool:
	if p_object.get_script() == avatar_definition_const:
		return true
	else:
		return false

func _make_visible(p_visible : bool) -> void:
	if (p_visible):
		if avatar_definition_editor:
			if avatar_definition_editor.options:
				avatar_definition_editor.options.show()
	else:
		if avatar_definition_editor:
			if avatar_definition_editor.options:
				avatar_definition_editor.options.hide()
			avatar_definition_editor.edit(null)
