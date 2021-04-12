extends Control

const avater_debug_const = preload("avatar_debug.gd")
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

const avatar_fixer_const = preload("avatar_fixer.gd")

const bone_direction_const = preload("bone_direction.gd")
const rotation_fixer_const = preload("rotation_fixer.gd")
const t_poser_const = preload("t_poser.gd")
const external_transform_fixer_const = preload("external_transform_fixer.gd")

const OUTPUT_SCENE_EXTENSION = "scn"

enum {
	MENU_OPTION_DEBUG_BONES
	MENU_OPTION_CORRECT_BONE_DIRECTIONS,
	MENU_OPTION_ENFORCE_STANDARD_T_POSE,
	MENU_OPTION_ENFORCE_STRICT_T_POSE,
	MENU_OPTION_SETUP_BONES
	MENU_OPTION_FIX_ALL
	MENU_OPTION_EXPORT_AVATAR
	MENU_OPTION_UPLOAD_AVATAR
}

func debug_bones(p_skeleton: Skeleton) -> void:
	avater_debug_const.debug_bones(node._skeleton_node)
	
	
func correct_bone_directions(p_root: Node, p_skeleton_node: Skeleton, p_humanoid_data: HumanoidData) -> void:
	bone_direction_const.fix_skeleton(p_root, p_skeleton_node, p_humanoid_data)

func enforce_standard_t_pose(p_root: Node, p_skeleton_node: Skeleton, p_humanoid_data: HumanoidData) -> void:
	t_poser_const.enforce_standard_t_pose(p_root, p_skeleton_node, p_humanoid_data)

func enforce_strict_t_pose(p_root: Node, p_skeleton_node: Skeleton, p_humanoid_data: HumanoidData) -> void:
	var base_pose_array: Array = []
	for i in range(0, p_skeleton_node.get_bone_count()):
		base_pose_array.push_back(p_skeleton_node.get_bone_rest(i))
	
	t_poser_const.enforce_strict_t_pose(p_root, p_skeleton_node, p_humanoid_data, base_pose_array)

func setup_bones_menu() -> int:
	if !node.humanoid_data:
		return avatar_callback_const.NO_HUMANOID_DATA
	if !node._skeleton_node:
		return avatar_callback_const.SKELETON_IS_NULL
	
	bone_mapper_dialog.set_humanoid_data(node.humanoid_data)
	bone_mapper_dialog.set_skeleton(node._skeleton_node)
	bone_mapper_dialog.popup_centered()
	
	return avatar_callback_const.AVATAR_OK

func export_avatar_local() -> void:
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
		var vsk_editor = get_node_or_null("/root/VSKEditor")
		if vsk_editor:
			var export_data_callback: FuncRef = FuncRef.new()
			export_data_callback.set_instance(self)
			export_data_callback.set_function("get_export_data")
			
			vsk_editor.show_upload_panel(export_data_callback, vsk_types_const.UserContentType.Avatar)
		else:
			printerr("Could not load VSKEditor!")
	else:
		printerr("Node is not valid!")


func edit(p_node : Node) -> void:
	node = p_node
	update_menu_options()


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
				correct_bone_directions(node, node._skeleton_node, node.humanoid_data)
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_ENFORCE_STANDARD_T_POSE:
			if check_if_avatar_is_valid():
				enforce_standard_t_pose(node, node._skeleton_node, node.humanoid_data)
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_ENFORCE_STRICT_T_POSE:
			if check_if_avatar_is_valid():
				enforce_strict_t_pose(node, node._skeleton_node, node.humanoid_data)
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_SETUP_BONES:
			if check_if_avatar_is_valid():
				err = setup_bones_menu()
			else:
				err = avatar_callback_const.ROOT_IS_NULL
		MENU_OPTION_FIX_ALL:
			if check_if_avatar_is_valid():
				err = avatar_fixer_const.fix_avatar(node, node._skeleton_node, node.humanoid_data)
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
	var vsk_exporter: Node = get_node_or_null("/root/VSKExporter")
	
	var err: int = avatar_callback_const.EXPORTER_NODE_LOADED
	if vsk_exporter:
		err = vsk_exporter.export_avatar(editor_plugin.get_editor_interface().get_edited_scene_root(),\
		node,\
		p_string)
	
	error_callback(err)

func _notification(what):
	match what:
		NOTIFICATION_PREDELETE:
			if editor_plugin:
				editor_plugin.remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, options)

func update_menu_options() -> void:
	if options:
		options.get_popup().clear()
		
		options.get_popup().add_item("Setup Bones", MENU_OPTION_SETUP_BONES)
		if VSKDebugManager.developer_mode:
			options.get_popup().add_item("Debug Bones", MENU_OPTION_DEBUG_BONES)
			options.get_popup().add_item("Correct Bone Directions", MENU_OPTION_CORRECT_BONE_DIRECTIONS)
			options.get_popup().add_item("Enforce Standard T-Pose", MENU_OPTION_ENFORCE_STANDARD_T_POSE)
			options.get_popup().add_item("Enforce Strict T-Pose", MENU_OPTION_ENFORCE_STRICT_T_POSE)
			options.get_popup().add_item("Fix All", MENU_OPTION_FIX_ALL)
		options.get_popup().add_item("Export Avatar Locally", MENU_OPTION_EXPORT_AVATAR)
		options.get_popup().add_item("Upload Avatar", MENU_OPTION_UPLOAD_AVATAR)

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
	
	options.get_popup().connect("id_pressed", self, "_menu_option")
	options.hide()
