@tool
extends Control

const vsk_types_const = preload("res://addons/vsk_importer_exporter/vsk_types.gd")
const avatar_callback_const = preload("avatar_callback.gd")

const bone_mapper_dialog_const = preload("bone_mapper_dialog.gd")
const bone_lib_const = preload("bone_lib.gd")

const hand_pose_const = preload("hand_pose.gd")
const hand_pose_exporter_const = preload("hand_pose_extractor.gd")

var editor_plugin: EditorPlugin = null

var node : Node = null
var err_dialog : AcceptDialog = null

var save_dialog : FileDialog = null

var bone_mapper_dialog : AcceptDialog = null

var bone_icon: Texture = null
var clear_icon: Texture = null

const humanoid_data_const = preload("humanoid_data.gd")

const avatar_fixer_const = preload("avatar_fixer.gd")

const bone_direction_const = preload("bone_direction.gd")
const rotation_fixer_const = preload("rotation_fixer.gd")
const t_poser_const = preload("t_poser.gd")
const external_transform_fixer_const = preload("external_transform_fixer.gd")

const OUTPUT_SCENE_EXTENSION = "scn"
const OUTPUT_HAND_RESOURCE_EXTENSION = "tres"

enum {
	MENU_OPTION_EXPORT_LEFT_HAND_POSE,
	MENU_OPTION_EXPORT_RIGHT_HAND_POSE,
	MENU_OPTION_CORRECT_BONE_DIRECTIONS,
	MENU_OPTION_SETUP_BONES,
	MENU_OPTION_FIX_ALL,
	MENU_OPTION_EXPORT_AVATAR,
	MENU_OPTION_UPLOAD_AVATAR,
}

enum {
	SAVE_OPTION_AVATAR,
	SAVE_OPTION_LEFT_HAND_POSE,
	SAVE_OPTION_RIGHT_HAND_POSE,
}

var save_option: int = SAVE_OPTION_AVATAR

static func correct_bone_directions(p_root: Node, p_skeleton_node: Skeleton3D, p_humanoid_data: HumanoidData, p_undo_redo: UndoRedo) -> void:
	bone_direction_const.fix_skeleton(p_root, p_skeleton_node, p_humanoid_data, p_undo_redo)

func enforce_strict_t_pose(p_root: Node, p_skeleton_node: Skeleton3D, p_humanoid_data: HumanoidData) -> void:
	var base_pose_array: Array = []
	for i in range(0, p_skeleton_node.get_bone_count()):
		base_pose_array.push_back(p_skeleton_node.get_bone_rest(i))
	
	t_poser_const.enforce_strict_t_pose(p_root, p_skeleton_node, p_humanoid_data, base_pose_array)

func setup_bones_menu() -> int:
	if !node.humanoid_data:
		return avatar_callback_const.NO_HUMANOID_DATA
	if !node._skeleton_node:
		return avatar_callback_const.SKELETON_IS_NULL
	
	assert(bone_mapper_dialog)
	bone_mapper_dialog.set_humanoid_data(node.humanoid_data)
	bone_mapper_dialog.set_skeleton(node._skeleton_node)
	bone_mapper_dialog.popup_centered_ratio() # Was without ratio but now broken
	
	return avatar_callback_const.AVATAR_OK

func export_avatar_local() -> void:
	save_option = SAVE_OPTION_AVATAR
	
	assert(save_dialog)
	save_dialog.add_filter("*.%s;%s" % [OUTPUT_SCENE_EXTENSION, OUTPUT_SCENE_EXTENSION.to_upper()]);
	
	save_dialog.popup_centered_ratio()
	save_dialog.set_title("Save Avatar As...")
	

func get_export_data() -> Dictionary:
	return {
		"root":editor_plugin.get_editor_interface().get_edited_scene_root(),
		"node":node,
	}


func export_avatar_upload() -> void:
	if node and node is Node:
		var vsk_editor = $"/root/VSKEditor"
		if vsk_editor:
			vsk_editor.show_upload_panel(self.get_export_data, vsk_types_const.UserContentType.Avatar)
		else:
			printerr("Could not load VSKEditor!")
	else:
		printerr("Node is not valid!")

func export_hand_pose(p_is_right_hand: bool) -> void:
	if node and node is Node:
		if p_is_right_hand:
			save_option = SAVE_OPTION_RIGHT_HAND_POSE
		else:
			save_option = SAVE_OPTION_LEFT_HAND_POSE
		
		assert(save_dialog)
		save_dialog.add_filter("*.%s;%s" % [OUTPUT_HAND_RESOURCE_EXTENSION, OUTPUT_HAND_RESOURCE_EXTENSION.to_upper()]);
		
		save_dialog.popup_centered_ratio()
		save_dialog.set_title("Save Hand Pose As...")


func edit(p_node : Node) -> void:
	node = p_node

func error_callback(p_err: int) -> void:
	if p_err != avatar_callback_const.AVATAR_OK:
		var error_str: String = avatar_callback_const.get_error_str(p_err)
		
		printerr(error_str)
		if err_dialog:
			err_dialog.set_text(error_str)
			err_dialog.popup_centered_clamped()


func check_if_avatar_is_valid() -> bool:
	if ! node:
		return false
		
	return true


func menu_option(p_id : int) -> void:
	var err: int = avatar_callback_const.AVATAR_OK
	match p_id:
		MENU_OPTION_CORRECT_BONE_DIRECTIONS:
			if check_if_avatar_is_valid():
				correct_bone_directions(node, node._skeleton_node, node.humanoid_data, editor_plugin.get_undo_redo())
				_refresh_skeleton(node._skeleton_node)
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_SETUP_BONES:
			if check_if_avatar_is_valid():
				err = setup_bones_menu()
				_refresh_skeleton(node._skeleton_node)
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_FIX_ALL:
			if check_if_avatar_is_valid():
				err = avatar_fixer_const.fix_avatar(node, node._skeleton_node, node.humanoid_data, editor_plugin.get_undo_redo())
				_refresh_skeleton(node._skeleton_node)
				menu_option(MENU_OPTION_CORRECT_BONE_DIRECTIONS)
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_EXPORT_AVATAR:
			if check_if_avatar_is_valid():
				export_avatar_local()
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_UPLOAD_AVATAR:
			if check_if_avatar_is_valid():
				_refresh_skeleton(node._skeleton_node)
				menu_option(MENU_OPTION_FIX_ALL)
				_refresh_skeleton(node._skeleton_node)
				export_avatar_upload()
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_EXPORT_LEFT_HAND_POSE:
			if check_if_avatar_is_valid():
				export_hand_pose(false)
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_EXPORT_RIGHT_HAND_POSE:
			if check_if_avatar_is_valid():
				export_hand_pose(true)
			else:
				err = avatar_callback_const.ROOT_IS_NULL
				
	error_callback(err)
	
static func _refresh_skeleton(p_skeleton : Skeleton3D):
	p_skeleton.visible = not p_skeleton.visible
	p_skeleton.visible = not p_skeleton.visible

func _save_file_at_path(p_path : String) -> void:
	var vsk_exporter: Node = get_node_or_null("/root/VSKExporter")
	
	var err: int = avatar_callback_const.AVATAR_FAILED
	
	if save_option == SAVE_OPTION_AVATAR:
		if vsk_exporter:
			err = vsk_exporter.export_avatar(editor_plugin.get_editor_interface().get_edited_scene_root(),\
			node,\
			p_path)	
		else:
			err = avatar_callback_const.AVATAR_FAILED
		
	elif save_option == SAVE_OPTION_LEFT_HAND_POSE or \
		save_option == SAVE_OPTION_RIGHT_HAND_POSE:
		err = avatar_callback_const.AVATAR_COULD_NOT_EXPORT_HANDS
		if node:
			var skeleton: Skeleton3D = node._skeleton_node
			var humanoid_data: HumanoidData = node.humanoid_data
			if skeleton and humanoid_data:
				
				var hand_pose: RefCounted = \
				hand_pose_exporter_const.generate_hand_pose_from_skeleton(
					skeleton,
					humanoid_data,
					true if save_option == SAVE_OPTION_RIGHT_HAND_POSE else false
				)
					
				if hand_pose:
					if ResourceSaver.save(
						p_path,
						hand_pose,
						ResourceSaver.FLAG_RELATIVE_PATHS
					) & 0xffffffff == OK:
						
						err = avatar_callback_const.AVATAR_OK
						
	error_callback(err)
	
func setup_dialogs() -> void:
	err_dialog = AcceptDialog.new()
	editor_plugin.get_editor_interface().get_base_control().add_child(err_dialog)
	
	save_dialog = FileDialog.new()
	save_dialog.mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.exclusive = true
	save_dialog.connect("file_selected", Callable(self, "_save_file_at_path"))
	editor_plugin.get_editor_interface().get_base_control().add_child(save_dialog)
	
	bone_mapper_dialog = bone_mapper_dialog_const.new(bone_icon, clear_icon)
	editor_plugin.get_editor_interface().get_base_control().add_child(bone_mapper_dialog)
	
func teardown_dialogs() -> void:
	if err_dialog:
		if err_dialog.is_inside_tree():
			err_dialog.get_parent().remove_child(err_dialog)
		err_dialog.queue_free()
		
	if save_dialog:
		if save_dialog.is_inside_tree():
			save_dialog.get_parent().remove_child(err_dialog)
		save_dialog.queue_free()
		
	if bone_mapper_dialog:
		if bone_mapper_dialog.is_inside_tree():
			bone_mapper_dialog.get_parent().remove_child(err_dialog)
		bone_mapper_dialog.queue_free()
	
func _enter_tree():
	setup_dialogs()
	
func _exit_tree():
	teardown_dialogs()
	
func _init(p_editor_plugin: EditorPlugin, p_clear_icon: Texture, p_bone_icon: Texture):		
	editor_plugin = p_editor_plugin
	
	bone_icon = p_bone_icon
	clear_icon = p_clear_icon
