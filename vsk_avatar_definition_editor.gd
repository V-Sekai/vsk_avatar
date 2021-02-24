extends Control

const avater_debug_const = preload("avatar_debug.gd")
const bone_direction_const = preload("bone_direction.gd")
const vsk_types_const = preload("res://addons/vsk_importer_exporter/vsk_types.gd")
const avatar_callback_const = preload("avatar_callback.gd")

const bone_mapper_dialog_const = preload("bone_mapper_dialog.gd")
const bone_lib_const = preload("bone_lib.gd")

var editor_plugin : EditorPlugin = null

var node : Node = null
var options : MenuButton = null
var err_dialog : AcceptDialog = null

var save_dialog : FileDialog = null

var bone_mapper_dialog : bone_mapper_dialog_const = null

const humanoid_data_const = preload("humanoid_data.gd")
const ik_pose_fixer_const = preload("ik_pose_fixer.gd")

var ik_pose_fixer : Reference = null

const rotation_fixer_const = preload("rotation_fixer.gd")
var rotation_fixer : Reference = null

const external_transform_fixer_const = preload("external_transform_fixer.gd")
var external_transform_fixer : Reference = null

const OUTPUT_SCENE_EXTENSION = "scn"

enum {
	MENU_OPTION_DEBUG_BONES
	MENU_OPTION_CORRECT_BONE_DIRECTIONS,
	MENU_OPTION_SETUP_BONES
	MENU_OPTION_ENFORCE_T_POSE
	MENU_OPTION_FIX_ALL
	MENU_OPTION_EXPORT_AVATAR
	MENU_OPTION_UPLOAD_AVATAR
}

func debug_bones(p_skeleton: Skeleton) -> void:
	avater_debug_const.debug_bones(node._skeleton_node)
	
	
func correct_bone_directions(p_skeleton_node: Skeleton, p_humanoid_data: HumanoidData) -> void:
	bone_direction_const.fix_skeleton(p_skeleton_node, p_humanoid_data)


func setup_bones_menu() -> int:
	if !node.humanoid_data:
		return avatar_callback_const.NO_HUMANOID_DATA
	if !node._skeleton_node:
		return avatar_callback_const.SKELETON_IS_NULL
	
	bone_mapper_dialog.set_humanoid_data(node.humanoid_data)
	bone_mapper_dialog.set_skeleton(node._skeleton_node)
	bone_mapper_dialog.popup_centered()
	
	return avatar_callback_const.AVATAR_OK


func setup_ik_t_pose(p_roll_fix_pass : bool) -> int:
	var ik_pose_fixer_output: Dictionary = ik_pose_fixer.setup_ik_t_pose(node, node._skeleton_node, node.humanoid_data, p_roll_fix_pass)
	
	for i in range(0, node._skeleton_node.get_bone_count()):
		node._skeleton_node.set_bone_pose(i, node._skeleton_node.get_bone_pose(i) * ik_pose_fixer_output["custom_bone_pose_array"][i])
	
	return ik_pose_fixer_output["result"]


func export_avatar_local() -> void:
	save_dialog.add_filter("*.%s;%s" % [OUTPUT_SCENE_EXTENSION, OUTPUT_SCENE_EXTENSION.to_upper()]);
	
	save_dialog.popup_centered_ratio()
	save_dialog.set_title("Save Avatar As...")


func get_export_data() -> Dictionary:
	return {
		"root":editor_plugin.get_editor_interface().get_edited_scene_root(),
		"node":node,
		"ik_pose_fixer":ik_pose_fixer,
		"rotation_fixer":rotation_fixer,
		"external_transform_fixer":external_transform_fixer
	}


func export_avatar_upload() -> void:
	if node and node is Node:
		var export_data_callback: FuncRef = FuncRef.new()
		export_data_callback.set_instance(self)
		export_data_callback.set_function("get_export_data")
		
		VSKEditor.show_upload_panel(export_data_callback, vsk_types_const.UserContentType.Avatar)
	else:
		printerr("Node is not valid!")


func edit(p_node : Node) -> void:
	node = p_node


func error_callback(p_err: int) -> void:
	if p_err != avatar_callback_const.AVATAR_OK:
		var error_string: String = avatar_callback_const.get_error_string(p_err)
		
		printerr(error_string)
		err_dialog.set_text(error_string)
		err_dialog.popup_centered_minsize()


func check_if_avatar_is_valid() -> bool:
	if ! node:
		return false
		
	return true


func _menu_option(p_id : int) -> void:
	var err: int = avatar_callback_const.AVATAR_OK
	match p_id:
		MENU_OPTION_DEBUG_BONES:
			if check_if_avatar_is_valid():
				debug_bones(node._skeleton_node)
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_CORRECT_BONE_DIRECTIONS:
			if check_if_avatar_is_valid():
				correct_bone_directions(node._skeleton_node, node.humanoid_data)
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_SETUP_BONES:
			if check_if_avatar_is_valid():
				err = setup_bones_menu()
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_ENFORCE_T_POSE:
			if check_if_avatar_is_valid():
				err = setup_ik_t_pose(true)
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_FIX_ALL:
			if check_if_avatar_is_valid():
				var ik_pose_output: Dictionary = ik_pose_fixer.setup_ik_t_pose(
					node,
					node._skeleton_node,
					node.humanoid_data,
					true)
				if ik_pose_output["result"] == avatar_callback_const.AVATAR_OK:
					var rotation_fixer_err: int = rotation_fixer.fix_rotations(
						node,
						node._skeleton_node,
						node.humanoid_data,
						ik_pose_output["custom_bone_pose_array"])
					if rotation_fixer_err == avatar_callback_const.AVATAR_OK:
						err = external_transform_fixer.fix_external_transform(node, node._skeleton_node)
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_EXPORT_AVATAR:
			if check_if_avatar_is_valid():
				export_avatar_local()
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_UPLOAD_AVATAR:
			if check_if_avatar_is_valid():
				export_avatar_upload()
			else:
				err = avatar_callback_const.ROOT_IS_NULL
				
	error_callback(err)

func _save_file_at_path(p_string : String) -> void:
	var err: int = VSKExporter.export_avatar(editor_plugin.get_editor_interface().get_edited_scene_root(),\
	node,\
	p_string,\
	ik_pose_fixer,\
	rotation_fixer,
	external_transform_fixer)
	
	error_callback(err)

func _notification(what):
	match what:
		NOTIFICATION_PREDELETE:
			if editor_plugin:
				editor_plugin.remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, options)

func _init(p_editor_plugin : EditorPlugin) -> void:
	editor_plugin = p_editor_plugin
	
	err_dialog = AcceptDialog.new()
	add_child(err_dialog)
	
	save_dialog = FileDialog.new()
	save_dialog.mode = FileDialog.MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.popup_exclusive = true
	save_dialog.connect("file_selected", self, "_save_file_at_path")
	add_child(save_dialog)
	
	var clear_icon: Texture = editor_plugin.get_editor_interface().get_base_control().get_icon("Clear", "EditorIcons")
	var bone_icon: Texture = editor_plugin.get_editor_interface().get_base_control().get_icon("BoneAttachment", "EditorIcons")
	
	bone_mapper_dialog = bone_mapper_dialog_const.new(bone_icon, clear_icon)
	add_child(bone_mapper_dialog)
	
	options = MenuButton.new()
	options.set_switch_on_hover(true)
	
	editor_plugin.add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, options)
	options.set_text("Avater Definition")
	options.get_popup().add_item("Debug Bones", MENU_OPTION_DEBUG_BONES)
	options.get_popup().add_item("Correct Bone Directions", MENU_OPTION_CORRECT_BONE_DIRECTIONS)
	options.get_popup().add_item("Setup Bones", MENU_OPTION_SETUP_BONES)
	options.get_popup().add_item("Enforce T-Pose", MENU_OPTION_ENFORCE_T_POSE)
	options.get_popup().add_item("Fix All", MENU_OPTION_FIX_ALL)
	options.get_popup().add_item("Export Avatar", MENU_OPTION_EXPORT_AVATAR)
	options.get_popup().add_item("Upload Avatar", MENU_OPTION_UPLOAD_AVATAR)
	
	options.get_popup().connect("id_pressed", self, "_menu_option")
	options.hide()
	
func _ready():
	ik_pose_fixer = Reference.new()
	ik_pose_fixer.set_script(ik_pose_fixer_const)
	
	rotation_fixer = Reference.new()
	rotation_fixer.set_script(rotation_fixer_const)
	
	external_transform_fixer = Reference.new()
	external_transform_fixer.set_script(external_transform_fixer_const)
