@tool
extends RefCounted

const math_funcs_const = preload("res://addons/math_util/math_funcs.gd")
const node_util_const = preload("res://addons/gd_util/node_util.gd")
const avatar_lib_const = preload("avatar_lib.gd")
const avatar_constants_const = preload("avatar_constants.gd")
const avatar_callback_const = preload("avatar_callback.gd")
const array_util_const = preload("res://addons/gd_util/array_util.gd")
const humanoid_data_const = preload("res://addons/vsk_avatar/humanoid_data.gd")
const bone_lib_const = preload("bone_lib.gd")

const APPLY_AS_REST = true


const SPINE_BASIS_GLOBAL = Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0))

const LEFT_ARM_BASIS_GLOBAL = Basis(Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0))
const RIGHT_ARM_BASIS_GLOBAL = Basis(Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0))
const LEGS_BASIS_GLOBAL = Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0), Vector3(0.0, 0.0, 1.0)) 
const FOOT_BASIS_GLOBAL = Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, -0.707, 0.707), Vector3(0.0, 0.707, 0.707)) * \
	Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.707, -0.707), Vector3(0.0, 0.707, 0.707))

static func fix_bone_chain(
	p_skeleton: Skeleton3D,
	p_reference_basis: Basis,
	p_bone_chain: Array,
	p_base_pose_local_offsets: Array,
	p_t_pose_local_offsets: Array,
	p_rotation_fix_data: Dictionary) -> Dictionary:
	for id in p_bone_chain:
		
		var global_pose : Transform3D = bone_lib_const.get_bone_global_transform(id, p_skeleton, 
		[
			p_base_pose_local_offsets,
			p_t_pose_local_offsets
		])

		var difference: Basis = p_reference_basis.inverse() * global_pose.basis
		
		p_rotation_fix_data["bind_pose_fixes"][id] *= Transform3D(difference)
		p_rotation_fix_data["bone_pose_roll_fixes"][id] *= Transform3D(difference.inverse())
		
		for child_id in p_skeleton.get_bone_children(id):
			var base_transform : Transform3D = p_base_pose_local_offsets[child_id]
			p_rotation_fix_data["bone_pose_roll_fixes"][child_id] = base_transform.inverse() * (Transform3D(difference) * base_transform)
		
	return p_rotation_fix_data
	
static func get_fixed_rotations(p_root: Node3D, p_skeleton: Skeleton3D, p_humanoid_data: HumanoidData, p_base_pose_local_offsets: Array, p_t_pose_local_offsets: Array) -> Dictionary:
	
	var base_transform: Transform3D = \
	node_util_const.get_relative_global_transform(p_root, p_skeleton)
	
	var base_transform_with_root: Transform3D = \
	base_transform * \
	avatar_lib_const.get_root_transform(p_skeleton, p_skeleton.get_bone_parent(avatar_lib_const.get_hips(p_skeleton, p_humanoid_data)))
	
	var rotation_fix_data: Dictionary = {"bone_pose_roll_fixes":[], "bind_pose_fixes":[]}
	
	for _i in range(0, p_skeleton.get_bone_count()):
		rotation_fix_data["bone_pose_roll_fixes"].push_back(Transform3D())
		rotation_fix_data["bind_pose_fixes"].push_back(Transform3D())
		
	# Correct any root bones between the root and hip
	rotation_fix_data = fix_bone_chain(
		p_skeleton,
		base_transform.basis * SPINE_BASIS_GLOBAL,
		avatar_lib_const.get_root_chain(p_skeleton, p_humanoid_data),
		p_base_pose_local_offsets,
		p_t_pose_local_offsets,
		rotation_fix_data)
	
	# TODO, figure out how to handle the head
	rotation_fix_data = fix_bone_chain(
		p_skeleton,
		base_transform_with_root.basis * SPINE_BASIS_GLOBAL,
		avatar_lib_const.get_full_spine_chain(p_skeleton, p_humanoid_data),
		p_base_pose_local_offsets,
		p_t_pose_local_offsets,
		rotation_fix_data)
		
	for side in range(avatar_constants_const.SIDE_LEFT, avatar_constants_const.SIDE_RIGHT+1):
		rotation_fix_data = fix_bone_chain(
			p_skeleton,
			base_transform_with_root.basis * LEGS_BASIS_GLOBAL,
			avatar_lib_const.get_leg_chain(p_skeleton, p_humanoid_data, side),
			p_base_pose_local_offsets,
			p_t_pose_local_offsets,
			rotation_fix_data)
		
		var p_arm_reference_basis: Basis = Basis()
		match side:
			avatar_constants_const.SIDE_LEFT:
				p_arm_reference_basis = LEFT_ARM_BASIS_GLOBAL
			avatar_constants_const.SIDE_RIGHT:
				p_arm_reference_basis = RIGHT_ARM_BASIS_GLOBAL
				
		rotation_fix_data = fix_bone_chain(
			p_skeleton,
			base_transform_with_root.basis * p_arm_reference_basis,
			avatar_lib_const.get_arm_chain(p_skeleton, p_humanoid_data, side),
			p_base_pose_local_offsets,
			p_t_pose_local_offsets,
			rotation_fix_data)
			
		for digit in range(avatar_constants_const.DIGIT_THUMB, avatar_constants_const.DIGIT_LITTLE+1):
			rotation_fix_data = fix_bone_chain(
				p_skeleton,
				base_transform_with_root.basis * p_arm_reference_basis,
				avatar_lib_const.get_digit_chain(p_skeleton, p_humanoid_data, side, digit),
				p_base_pose_local_offsets,
				p_t_pose_local_offsets,
				rotation_fix_data)
				
	return rotation_fix_data
	
static func fix_rotations(p_root: Node3D, p_skeleton: Skeleton3D, p_humanoid_data: HumanoidData, p_t_pose_local_offsets: Array) -> int:
	print("---Running RotationFixer---")
	
	var err: int = avatar_callback_const.generic_error_check(p_root, p_skeleton)
	if err != avatar_callback_const.AVATAR_OK:
		return err
		
	var rest_pose_local_offsets: Array = []
	
	for i in range(0, p_skeleton.get_bone_count()):
		rest_pose_local_offsets.push_back(p_skeleton.get_bone_rest(i))
		
	var rotation_fix_data: Dictionary = get_fixed_rotations(p_root, p_skeleton, p_humanoid_data, rest_pose_local_offsets, p_t_pose_local_offsets)
	
	for i in range(0, p_skeleton.get_bone_count()):
		var t: Transform3D = rotation_fix_data["bone_pose_roll_fixes"][i]
		p_skeleton.set_bone_pose_position(i, t.origin)
		p_skeleton.set_bone_pose_rotation(i, t.basis.get_rotation_quaternion())
		p_skeleton.set_bone_pose_scale(i, t.basis.get_scale())
		
	# Fix to skins
	var mesh_instances: Array = avatar_lib_const.find_mesh_instances_for_avatar_skeleton(p_root, p_root._skeleton_node, [])
	var skins: Array = []
	
	for mesh_instance in mesh_instances:
		if mesh_instance.skin:
			skins.push_back(mesh_instance.skin.duplicate())
			
		else:
			skins.push_back(null)
			
	if skins.size() == mesh_instances.size():
		for i in range(0, mesh_instances.size()):
			mesh_instances[i].skin = skins[i]
	else:
		return avatar_callback_const.SKIN_MESH_INSTANCE_SIZE_MISMATCH
	
	for skin in skins:
		for bind_i in range(0, skin.get_bind_count()):
			var bone_index:int  = skin.get_bind_bone(bind_i)
			if (bone_index == -1):
				var bind_name: String = skin.get_bind_name(bind_i)
				if bind_name.is_empty():
					continue
				bone_index = p_skeleton.find_bone(bind_name)
				
			if (bone_index == -1):
				continue
			
			skin.set_bind_pose(bind_i, Transform3D(rotation_fix_data["bind_pose_fixes"][bone_index]) * skin.get_bind_pose(bind_i))
	
	if skins.size() == mesh_instances.size():
		for i in range(0, mesh_instances.size()):
			mesh_instances[i].skin = skins[i]
	else:
		return avatar_callback_const.SKIN_MESH_INSTANCE_SIZE_MISMATCH
	
	
	return avatar_callback_const.AVATAR_OK
