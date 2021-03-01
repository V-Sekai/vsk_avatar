extends Node


const avatar_lib_const = preload("avatar_lib.gd")
const humanoid_data_const = preload("humanoid_data.gd")

const bone_direction_const = preload("bone_direction.gd")
const rotation_fixer_const = preload("rotation_fixer.gd")
const t_poser_const = preload("t_poser.gd")
const external_transform_fixer_const = preload("external_transform_fixer.gd")

const avatar_callback_const = preload("avatar_callback.gd")

static func _fix_meshes(p_bind_fix_array: Array, p_mesh_instances: Array) -> void:
	print("bone_direction: _fix_meshes")
	
	for mi in p_mesh_instances:
		var skin: Skin = mi.get_skin();
		if skin == null:
			continue
			
		skin = skin.duplicate()
		mi.set_skin(skin)
		var skeleton_path: NodePath = mi.get_skeleton_path()
		var node: Node = mi.get_node_or_null(skeleton_path)
		var skeleton: Skeleton = node
		for bind_i in range(0, skin.get_bind_count()):
			var bone_index:int  = skin.get_bind_bone(bind_i)
			if (bone_index == -1):
				var bind_name: String = skin.get_bind_name(bind_i)
				if bind_name.empty():
					continue
				bone_index = skeleton.find_bone(bind_name)
				
			if (bone_index == -1):
				continue
			skin.set_bind_pose(bind_i, p_bind_fix_array[bone_index] * skin.get_bind_pose(bind_i))

static func fix_avatar(p_root: Node, p_skeleton: Skeleton, p_humanoid_data: HumanoidData) -> int:
	var err: int = avatar_callback_const.AVATAR_OK
	
	var base_pose: Array = []
	for i in range(0, p_skeleton.get_bone_count()):
		base_pose.append(p_skeleton.get_bone_rest(i))
	
	var fortune_offsets: Dictionary = bone_direction_const.get_fortune_with_chain_offsets(p_root, p_skeleton, p_humanoid_data, base_pose)
	
	var direction_corrected_base_pose: Array = []
	for i in range(0, p_skeleton.get_bone_count()):
		direction_corrected_base_pose.append(base_pose[i] * fortune_offsets["base_pose_offsets"][i])

	var custom_t_pose_array: Array = t_poser_const.get_strict_t_pose(p_root, p_skeleton, p_humanoid_data, direction_corrected_base_pose)
	
	var rotation_fix_data: Dictionary = rotation_fixer_const.get_fixed_rotations(p_root, p_skeleton, p_humanoid_data, direction_corrected_base_pose, custom_t_pose_array)

	var final_base_pose: Array = []
	for i in range(0, p_skeleton.get_bone_count()):
		final_base_pose.append(direction_corrected_base_pose[i] * rotation_fix_data["bone_pose_roll_fixes"][i])

	# Now finally, apply it
	for i in range(0, final_base_pose.size()):
		p_skeleton.set_bone_rest(i, final_base_pose[i])
	
	# Correct the bind poses
	var final_bind_pose: Array = []
	for i in range(0, p_skeleton.get_bone_count()):
		final_bind_pose.append(rotation_fix_data["bind_pose_fixes"][i] * fortune_offsets["bind_pose_offsets"][i])

	
	var mesh_instances: Array = avatar_lib_const.find_mesh_instances_for_avatar_skeleton(p_root, p_skeleton, [])
	_fix_meshes(final_bind_pose, mesh_instances)

	err = external_transform_fixer_const.fix_external_transform(p_root, p_skeleton)
	
	return err
