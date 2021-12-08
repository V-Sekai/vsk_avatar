extends Node


const avatar_lib_const = preload("avatar_lib.gd")
const humanoid_data_const = preload("humanoid_data.gd")

const bone_direction_const = preload("bone_direction.gd")
const rotation_fixer_const = preload("rotation_fixer.gd")
const t_poser_const = preload("t_poser.gd")
const external_transform_fixer_const = preload("external_transform_fixer.gd")
const bone_lib = preload("bone_lib.gd")

const avatar_callback_const = preload("avatar_callback.gd")

static func fix_avatar(p_root: Node, p_skeleton: Skeleton3D, p_humanoid_data: HumanoidData, undo_redo: UndoRedo) -> int:
	undo_redo = UndoRedo.new()
	var err: int = avatar_callback_const.AVATAR_OK
	
	# First, copy the base rest pose from the skeleton into the base_pose array
	var base_pose: Array = [].duplicate()
	for i in range(0, p_skeleton.get_bone_count()):
		base_pose.append(p_skeleton.get_bone_rest(i))
	# Next get apply the fortune_with_chain_offsets algorithm which will return the offsets to the base pose required to get
	# all the bones to point their Y-direction to either the next bone in the humanoid chain, or the average of their children.
	# It will also return an array of transforms which when multiplied by the skin bind poses, will correct the mesh skinning.
	var fortune_offsets: Dictionary = bone_direction_const.get_fortune_with_chain_offsets(p_skeleton, p_humanoid_data, base_pose)
	
	# Create an array of the base pose transforms multiplied by the direction corrected offsets
	var direction_corrected_base_pose: Array = [].duplicate()
	for i in range(0, p_skeleton.get_bone_count()):
		direction_corrected_base_pose.append(base_pose[i] * fortune_offsets["base_pose_offsets"][i])

	# This function will return an array of transforms which when applied to the base pose, will force the character into a parallel
	# t-pose
	var custom_t_pose_array: Array = t_poser_const.get_strict_t_pose(p_root, p_skeleton, p_humanoid_data, direction_corrected_base_pose)
	
	# This function accepts a base pose and a parallel t-pose which will return the roll offsets required to make the base pose match
	# a standard reference rig. It will also return an array of transforms which when multiplied by the skin bind poses, will
	# compensate the mesh skinning for these corrections.
	var rotation_fix_data: Dictionary = rotation_fixer_const.get_fixed_rotations(p_root, p_skeleton, p_humanoid_data, direction_corrected_base_pose, custom_t_pose_array)

	# Construct the final pose by multiplying the direction corrected base pose with the data from the bone roll fix array
	var final_base_pose: Array = [].duplicate()
	for i in range(0, p_skeleton.get_bone_count()):
		final_base_pose.append(direction_corrected_base_pose[i] * rotation_fix_data["bone_pose_roll_fixes"][i])

	# Now finally, apply it to the original skeleton
	for i in range(0, final_base_pose.size()):
		var final_pose: Transform3D = final_base_pose[i]
		bone_lib.change_bone_rest(p_skeleton, i, final_pose)

	# Now combine the bind pose fix by combining the fix from the bone roll fix and the bone direction fix
	var final_bind_pose: Array = [].duplicate()
	for i in range(0, p_skeleton.get_bone_count()):
		final_bind_pose.append(rotation_fix_data["bind_pose_fixes"][i] * fortune_offsets["bind_pose_offsets"][i])

	# Search for all mesh instances with the associated skeleton and apply the bind pose fix to their respective meshes
	var mesh_instances: Array = avatar_lib_const.find_mesh_instances_for_avatar_skeleton(p_root, p_skeleton, [])
	bone_direction_const._fix_meshes(final_bind_pose, mesh_instances)

	# Apply the inverse transform of any nodes between the skeleton and the root node to fix any models
	err = external_transform_fixer_const.fix_external_transform(p_root, p_skeleton, undo_redo)
	
	return err
