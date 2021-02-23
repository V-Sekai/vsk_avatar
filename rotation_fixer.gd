extends Reference
tool

const node_util_const = preload("res://addons/gdutil/node_util.gd")
const avatar_constants_const = preload("avatar_constants.gd")
const avatar_callback_const = preload("avatar_callback.gd")
const array_util_const = preload("res://addons/gdutil/array_util.gd")
const humanoid_data_const = preload("res://addons/vsk_avatar/humanoid_data.gd")
const bone_lib_const = preload("bone_lib.gd")

const APPLY_AS_REST = false

const HIPS_BASIS_GLOBAL = Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0))
const HEAD_BASIS_GLOBAL = Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0))

const LEFT_ARM_BASIS_GLOBAL = Basis(Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0))
const RIGHT_ARM_BASIS_GLOBAL = Basis(Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0))
const LEGS_BASIS_GLOBAL = Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0), Vector3(0.0, 0.0, 1.0)) 
const FOOT_BASIS_GLOBAL = Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, -0.707, 0.707), Vector3(0.0, 0.707, 0.707)) * \
	Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.707, -0.707), Vector3(0.0, 0.707, 0.707))

#const LEFT_ARM_BASIS_LOCAL = Basis(Vector3(0.0, -1.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0))
#const RIGHT_ARM_BASIS_LOCAL = Basis(Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(1.0, 0.0, 0.0))
#const LEGS_BASIS_LOCAL = Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, -1.0))

static func get_bone_children(p_skeleton : Skeleton, p_id : int) -> PoolIntArray:
	var children : PoolIntArray = PoolIntArray()
	for i in range(0, p_skeleton.get_bone_count()):
		var parent_id : int = p_skeleton.get_bone_parent(i)
		if parent_id == p_id:
			children.append(i)
			
	return children
	
static func fix_bone(p_root: Spatial, p_skeleton: Skeleton, p_id: int, p_global_basis: Basis, p_transform_data: Dictionary) -> Dictionary:
	
	var skeleton_global_transform : Transform = Transform(Basis(\
	node_util_const.get_relative_global_transform(p_root, p_skeleton).basis.get_rotation_quat()),\
	node_util_const.get_relative_global_transform(p_root, p_skeleton).origin)
	
	var global_pose : Transform = skeleton_global_transform *\
	bone_lib_const.get_bone_global_transform(p_id, p_skeleton, 
	[
		p_transform_data["rest_bone_pose_array"],
		p_transform_data["bone_pose_array"],
		p_transform_data["custom_bone_pose_array"]
	])
	
	var custom_transform : Transform = p_transform_data["custom_bone_pose_array"][p_id]
	var difference : Quat = p_global_basis.inverse().get_rotation_quat() * global_pose.basis.get_rotation_quat()
	
	p_transform_data["custom_bone_pose_array"][p_id] = custom_transform * Transform(difference).inverse()
	p_transform_data["transform_offsets"][p_id] *= Transform(difference).inverse()
		
	#
	for child_id in get_bone_children(p_skeleton, p_id):
		var child_custom_transform : Transform = p_transform_data["custom_bone_pose_array"][child_id]
		var rest_transform : Transform = p_transform_data["rest_bone_pose_array"][child_id]
		
		var rotation_fix : Transform = rest_transform.inverse() * (Transform(difference) * rest_transform)

		var new_child_custom_transform : Transform = rotation_fix * child_custom_transform
		var child_transform_offset : Transform = child_custom_transform.inverse() * new_child_custom_transform
		
		p_transform_data["custom_bone_pose_array"][child_id] = child_custom_transform * child_transform_offset
		p_transform_data["transform_offsets"][child_id] *= child_transform_offset
		
	return p_transform_data

static func fix_chain(p_root: Spatial, p_skeleton: Skeleton, p_start_id: int, p_end_id: int, p_valid_bone_ids: PoolIntArray, p_global_basis: Basis, p_transform_data: Dictionary) -> Dictionary:
	var bone_chain : PoolIntArray = bone_lib_const.get_full_bone_chain(p_skeleton, p_start_id, p_end_id)
	
	for id in bone_chain:
		if array_util_const.pool_int_array_find(p_valid_bone_ids, id) != -1:
			p_transform_data = fix_bone(p_root, p_skeleton, id, p_global_basis, p_transform_data)
		
	return p_transform_data
	
static func fix_arm(p_root : Spatial, p_humanoid_data : humanoid_data_const, p_skeleton : Skeleton, p_transform_data: Dictionary, p_side : int) -> Dictionary:
	var direction_name : String = avatar_constants_const.get_name_for_side(p_side)
	var global_basis : Basis = LEFT_ARM_BASIS_GLOBAL if p_side == avatar_constants_const.SIDE_LEFT else RIGHT_ARM_BASIS_GLOBAL
	
	var upper_arm_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(\
	p_skeleton, p_humanoid_data, "upper_arm_%s_bone_name" % direction_name)
	
	var arm_start_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(\
	p_skeleton, p_humanoid_data, "shoulder_%s_bone_name" % direction_name)
	var arm_end_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(\
	p_skeleton, p_humanoid_data, "hand_%s_bone_name" % direction_name)
	var arm_middle_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(\
	p_skeleton, p_humanoid_data, "forearm_%s_bone_name" % direction_name)
	
	if arm_start_name == "":
		arm_start_name = upper_arm_name
		
	if arm_start_name == "" or arm_middle_name == "" or arm_end_name == "" or upper_arm_name == "":
		return p_transform_data

	var arm_start_id : int = p_skeleton.find_bone(arm_start_name)
	var arm_middle_id : int = p_skeleton.find_bone(arm_middle_name)
	var arm_end_id : int = p_skeleton.find_bone(arm_end_name)
	var upper_arm_id : int = p_skeleton.find_bone(upper_arm_name)
	
	if arm_start_id == -1 or arm_middle_id == -1 or arm_end_id == -1 or upper_arm_id == -1:
		return p_transform_data
	
	var valid_bone_ids : PoolIntArray = []
	valid_bone_ids.append(arm_start_id)
	valid_bone_ids.append(arm_middle_id)
	valid_bone_ids.append(arm_end_id)
	if array_util_const.pool_int_array_find(valid_bone_ids, upper_arm_id) == -1:
		valid_bone_ids.append(upper_arm_id)

	return fix_chain(p_root, p_skeleton, arm_start_id, arm_end_id, valid_bone_ids, global_basis, p_transform_data)
	
	
static func fix_digit(p_root: Spatial, p_humanoid_data: humanoid_data_const, p_skeleton: Skeleton, p_transform_data: Dictionary, p_side: int, p_digit_id: int, p_global_basis: Basis) -> Dictionary:
	var side_name : String = avatar_constants_const.get_name_for_side(p_side)
	var digit_name : String = ""
	
	digit_name = avatar_constants_const.get_name_for_digit(p_digit_id)
	
	var start_bone_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(p_skeleton, p_humanoid_data, \
	"%s_%s_%s_bone_name" % [digit_name, avatar_constants_const.PROXIMAL_NAME, side_name])
	var middle_bone_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(p_skeleton, p_humanoid_data, \
	"%s_%s_%s_bone_name" % [digit_name, avatar_constants_const.INTERMEDIATE_NAME, side_name])
	var end_bone_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(p_skeleton, p_humanoid_data, \
	"%s_%s_%s_bone_name" % [digit_name, avatar_constants_const.DISTAL_NAME, side_name])
	
	if start_bone_name == "" or middle_bone_name == "" or end_bone_name == "":
		return p_transform_data
		
	print("Got digit bone names!")
		
	print(start_bone_name)
	print(middle_bone_name)
	print(end_bone_name)
	
	var start_id : int = p_skeleton.find_bone(start_bone_name)
	var middle_id : int = p_skeleton.find_bone(middle_bone_name)
	var end_id : int = p_skeleton.find_bone(end_bone_name)
	
	if start_id == -1 or middle_id == -1 or end_id == -1:
		return p_transform_data
		
	print("Got digit bone IDs!")
		
	var valid_bone_ids : PoolIntArray = []
	valid_bone_ids.append(start_id)
	valid_bone_ids.append(middle_id)
	valid_bone_ids.append(end_id)
	
	p_transform_data = fix_chain(p_root, p_skeleton, start_id, end_id, valid_bone_ids, p_global_basis, p_transform_data)
	
	print("Digit Fixed!")
	
	return p_transform_data
	
static func fix_digits(p_root: Spatial, p_humanoid_data: humanoid_data_const, p_skeleton: Skeleton, p_transform_data: Dictionary, p_side: int) -> Dictionary:
	var direction_name : String = avatar_constants_const.get_name_for_side(p_side)
	var global_basis : Basis = LEFT_ARM_BASIS_GLOBAL if p_side == avatar_constants_const.SIDE_LEFT else RIGHT_ARM_BASIS_GLOBAL

	p_transform_data = fix_digit(p_root, p_humanoid_data, p_skeleton, p_transform_data, p_side, avatar_constants_const.DIGIT_THUMB, global_basis.rotated(Vector3(1.0, 0.0, 0.0), PI * 0.5))
	
	for i in range(avatar_constants_const.DIGIT_INDEX, avatar_constants_const.DIGIT_LITTLE):
		p_transform_data = fix_digit(p_root, p_humanoid_data, p_skeleton, p_transform_data, p_side, i, global_basis)
	
	return p_transform_data
	
static func fix_spine(p_root: Spatial, p_humanoid_data: humanoid_data_const, p_skeleton: Skeleton, p_transform_data: Dictionary) -> Dictionary:
	var hips_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(p_skeleton, p_humanoid_data, "hips_bone_name")
	var spine_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(p_skeleton, p_humanoid_data, "spine_bone_name")
	var chest_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(p_skeleton, p_humanoid_data, "chest_bone_name")
	var upper_chest_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(p_skeleton, p_humanoid_data, "upper_chest_bone_name")
	
	var spine_start_name : String = hips_name
	var spine_end_name : String = upper_chest_name
	
	if spine_end_name == "":
		spine_end_name = chest_name
		if spine_end_name == "":
			spine_end_name = spine_name
		
	if spine_start_name == "" or spine_end_name == "":
		return p_transform_data

	var hips_id : int = p_skeleton.find_bone(hips_name)
	var spine_id : int = p_skeleton.find_bone(spine_name)
	var chest_id : int = p_skeleton.find_bone(chest_name)
	var upper_chest_id : int = p_skeleton.find_bone(upper_chest_name)
	
	var spine_start_id : int = p_skeleton.find_bone(spine_start_name)
	var spine_end_id : int = p_skeleton.find_bone(spine_end_name)
	
	var valid_bone_ids : PoolIntArray = []
	if array_util_const.pool_int_array_find(valid_bone_ids, hips_id) == -1:
		valid_bone_ids.append(hips_id)
	if array_util_const.pool_int_array_find(valid_bone_ids, spine_id) == -1:
		valid_bone_ids.append(spine_id)
	if array_util_const.pool_int_array_find(valid_bone_ids, chest_id) == -1:
		valid_bone_ids.append(chest_id)
	if array_util_const.pool_int_array_find(valid_bone_ids, upper_chest_id) == -1:
		valid_bone_ids.append(upper_chest_id)

	return fix_chain(p_root, p_skeleton, spine_start_id, spine_end_id, valid_bone_ids, HIPS_BASIS_GLOBAL, p_transform_data)
	
static func fix_neck(p_root: Spatial, p_humanoid_data: humanoid_data_const, p_skeleton: Skeleton, p_transform_data: Dictionary) -> Dictionary:
	var global_basis : Basis = HEAD_BASIS_GLOBAL
	
	var neck_start_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(p_skeleton, p_humanoid_data, "neck_bone_name")
	var neck_end_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(p_skeleton, p_humanoid_data, "head_bone_name")
		
	if neck_start_name == "" or neck_end_name == "":
		return p_transform_data

	var neck_start_id : int = p_skeleton.find_bone(neck_start_name)
	var neck_end_id : int = p_skeleton.find_bone(neck_end_name)

	if neck_start_id == -1 or neck_end_id == -1:
		return p_transform_data

	var valid_bone_ids : PoolIntArray = []
	valid_bone_ids.append(neck_start_id)
	valid_bone_ids.append(neck_end_id)

	return fix_chain(p_root, p_skeleton, neck_start_id, neck_end_id, valid_bone_ids, global_basis, p_transform_data)

	
static func fix_leg(p_root: Spatial, p_humanoid_data: humanoid_data_const, p_skeleton: Skeleton, p_transform_data: Dictionary, p_side : int) -> Dictionary:
	var direction_name : String = avatar_constants_const.get_name_for_side(p_side)
	var global_basis : Basis = LEGS_BASIS_GLOBAL
	
	var leg_start_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(p_skeleton, p_humanoid_data, \
	"thigh_%s_bone_name" % direction_name)
	var leg_end_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(p_skeleton, p_humanoid_data, \
	"shin_%s_bone_name" % direction_name)
		
	if leg_start_name == "" or leg_end_name == "":
		return p_transform_data

	var leg_start_id : int = p_skeleton.find_bone(leg_start_name)
	var leg_end_id : int = p_skeleton.find_bone(leg_end_name)

	if leg_start_id == -1 or leg_end_id == -1:
		return p_transform_data

	var valid_bone_ids : PoolIntArray = []
	valid_bone_ids.append(leg_start_id)
	valid_bone_ids.append(leg_end_id)

	return fix_chain(p_root, p_skeleton, leg_start_id, leg_end_id, valid_bone_ids, global_basis, p_transform_data)
	
static func fix_foot(p_root: Spatial, p_humanoid_data: humanoid_data_const, p_skeleton: Skeleton, p_transform_data: Dictionary, p_side : int) -> Dictionary:
	var direction_name : String = avatar_constants_const.get_name_for_side(p_side)
	var global_basis : Basis = FOOT_BASIS_GLOBAL
	
	var foot_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(p_skeleton, p_humanoid_data, \
	"foot_%s_bone_name" % direction_name)
		
	if foot_name == "":
		return p_transform_data

	var foot_id : int = p_skeleton.find_bone(foot_name)

	if foot_id == -1:
		return p_transform_data

	return fix_bone(p_root, p_skeleton, foot_id, global_basis, p_transform_data)
	
static func fix_eye(p_root: Spatial, p_humanoid_data: humanoid_data_const, p_skeleton: Skeleton, p_transform_data: Dictionary, p_side : int) -> Dictionary:
	var direction_name : String = avatar_constants_const.get_name_for_side(p_side)
	var global_basis : Basis = HEAD_BASIS_GLOBAL

	var eye_name : String = bone_lib_const.get_internal_bone_name_for_humanoid_bone(p_skeleton, p_humanoid_data, \
	"eye_%s_bone_name" % direction_name)
		
	if eye_name == "":
		return p_transform_data

	var eye_id : int = p_skeleton.find_bone(eye_name)

	if eye_id == -1:
		return p_transform_data

	return fix_bone(p_root, p_skeleton, eye_id, global_basis, p_transform_data)

static func reset_skeleton_and_bind_pose(p_skeleton: Skeleton, p_skins: Array, p_default_skins: Array, p_default_pose_array: Array) -> Array:
		
	for i in range(0, p_skeleton.get_bone_count()):
		p_skeleton.set_bone_pose(i, p_default_pose_array[i])
	
	if p_skins.size() == p_default_skins.size():
		for i in range(0, p_skins.size()):
			if p_skins[i]:
				for j in range(0, p_skins[i].get_bind_count()):
					if p_default_skins[i] and p_default_skins[i].get_bind_pose(j) != null:
						p_skins[i].set_bind_pose(j, p_default_skins[i].get_bind_pose(j))

	return p_skins

static func apply_local_transform_to_bind_pose(p_bind_id : int, p_skeleton : Skeleton, p_skin : Skin, p_rest_transform_local_offsets : Array, p_custom_transform_local_offsets : Array) -> Skin:
	var rest_transform_local_offsets : Array = []
	var custom_transform_local_offsets : Array = []
	
	for i in range(0, p_skeleton.get_bone_count()):
		rest_transform_local_offsets.push_back(p_rest_transform_local_offsets[i])
		custom_transform_local_offsets.push_back(p_custom_transform_local_offsets[i])
	
	var bind_name = p_skin.get_bind_name(p_bind_id)
	var bind_bone_id : int = p_skeleton.find_bone(bind_name)
	if bind_bone_id == -1:
		bind_bone_id = p_skin.get_bind_bone(p_bind_id)
	
	var parent_bind_bone_id : int = p_skeleton.get_bone_parent(bind_bone_id)
	var bind_pose : Transform = p_skin.get_bind_pose(p_bind_id)
	
	var custom_transform : Transform = p_custom_transform_local_offsets[bind_bone_id]
	var rest_transform : Transform = p_rest_transform_local_offsets[bind_bone_id]
	
	var global_rest_transform : Transform = bone_lib_const.get_bone_global_transform(bind_bone_id, p_skeleton, [rest_transform_local_offsets])
	var parent_bone_chain : Array = []
	
	var rest_transform_chain : Array = []
	var custom_transform_chain : Array = []
	
	# Get all the bone ids in the chain for this bone
	while parent_bind_bone_id >= 0:
		parent_bone_chain.push_back(parent_bind_bone_id)
		parent_bind_bone_id = p_skeleton.get_bone_parent(parent_bind_bone_id)
	
	# Now build the chains
	for id in parent_bone_chain:
		var rest_parent_transform : Transform = Transform(p_rest_transform_local_offsets[id])
		var custom_parent_transform : Transform = Transform(p_custom_transform_local_offsets[id])
		rest_transform_chain.push_back(rest_parent_transform)
		custom_transform_chain.push_back(custom_parent_transform)
	
	# Put the current bones rest at the beginning of the chain for the
	# correct offsets
	rest_transform_chain.push_front(rest_transform)
	
	var resultant_transform : Transform = custom_transform
	for i in range(0, custom_transform_chain.size()):
		var offset_transform = Transform()
		for j in range(i, -1, -1):
			offset_transform = offset_transform * rest_transform_chain[j]
			
		resultant_transform = (offset_transform.inverse() * custom_transform_chain[i] * offset_transform) * resultant_transform
	
	var fixed_bind_pose : Transform = resultant_transform.inverse() * global_rest_transform.inverse() * global_rest_transform * bind_pose
	
	p_skin.set_bind_pose(p_bind_id, fixed_bind_pose)
	
	return p_skin

static func find_mesh_instances_for_skeleton(p_node: Node, p_skeleton: Skeleton, p_valid_mesh_instances: Array) -> Array:
	if p_skeleton and p_node is MeshInstance:
		var skeleton: Node = p_node.get_node_or_null(p_node.skeleton)
		if skeleton == p_skeleton:
			p_valid_mesh_instances.push_back(p_node)
			
	for child in p_node.get_children():
		p_valid_mesh_instances = find_mesh_instances_for_skeleton(child, p_skeleton, p_valid_mesh_instances)
	
	return p_valid_mesh_instances

static func fix_rotations_internal(p_root: Spatial, p_skeleton: Skeleton, p_humanoid_data: humanoid_data_const, p_skins: Array, p_default_skins: Array, p_custom_bone_pose_array: Array) -> Array:
		
	var bone_pose_array: Array = []
	var rest_transform_local_offsets : Array = []
	var t_pose_transform_local_offsets : Array = []
	var rotation_fix_transform_local_offsets : Array = []
	
	var custom_rotation_fix_array : Array = []
	
	for i in range(0, p_skeleton.get_bone_count()):
		rest_transform_local_offsets.push_back(p_skeleton.get_bone_rest(i))
		t_pose_transform_local_offsets.push_back(p_custom_bone_pose_array[i])
		bone_pose_array.push_back(p_skeleton.get_bone_pose(i))
	
		custom_rotation_fix_array.push_back(Transform())
		rotation_fix_transform_local_offsets.push_back(Transform())
	
	var transform_data: Dictionary = {
		"rest_bone_pose_array":rest_transform_local_offsets,
		"bone_pose_array":bone_pose_array,
		"custom_bone_pose_array":p_custom_bone_pose_array,
		"transform_offsets":rotation_fix_transform_local_offsets}
		
	transform_data = fix_spine(p_root, p_humanoid_data, p_skeleton, transform_data)
	transform_data = fix_neck(p_root, p_humanoid_data, p_skeleton, transform_data)
	transform_data = fix_eye(p_root, p_humanoid_data, p_skeleton, transform_data, false)
	transform_data = fix_eye(p_root, p_humanoid_data, p_skeleton, transform_data, true)
	transform_data = fix_arm(p_root, p_humanoid_data, p_skeleton, transform_data, false)
	transform_data = fix_arm(p_root, p_humanoid_data, p_skeleton, transform_data, true)
	transform_data = fix_leg(p_root, p_humanoid_data, p_skeleton, transform_data, false)
	transform_data = fix_leg(p_root, p_humanoid_data, p_skeleton, transform_data, true)
	transform_data = fix_foot(p_root, p_humanoid_data, p_skeleton, transform_data, false)
	transform_data = fix_foot(p_root, p_humanoid_data, p_skeleton, transform_data, true)
	transform_data = fix_digits(p_root, p_humanoid_data, p_skeleton, transform_data, avatar_constants_const.SIDE_LEFT)
	transform_data = fix_digits(p_root, p_humanoid_data, p_skeleton, transform_data, avatar_constants_const.SIDE_RIGHT)
	
	rotation_fix_transform_local_offsets = transform_data["transform_offsets"]
	
	var roll_global_offsets : Array = []
	var roll_local_offsets : Array = []

	# Figure out the global rotation offsets for each bone
	for i in range(0, p_skeleton.get_bone_count()):
		var global_rest_tposed_transform : Transform = bone_lib_const.get_bone_global_transform(i, p_skeleton, [rest_transform_local_offsets, t_pose_transform_local_offsets])
		var global_rest_tposed_rotated_transform : Transform = bone_lib_const.get_bone_global_transform(i, p_skeleton, [rest_transform_local_offsets, t_pose_transform_local_offsets, rotation_fix_transform_local_offsets])
		
		var roll_global_offset : Transform = global_rest_tposed_transform.inverse() * global_rest_tposed_rotated_transform
		roll_global_offsets.push_back(roll_global_offset)
		roll_local_offsets.push_back(Transform())
		
	# Now get the local rotations for everything
	for i in range(0, p_skeleton.get_bone_count()):
		roll_local_offsets[i] = roll_local_offsets[i] * roll_global_offsets[i]
		for child_id in get_bone_children(p_skeleton, i):
			var child_custom_transform : Transform = roll_local_offsets[child_id]
			var rest_transform : Transform = rest_transform_local_offsets[child_id]
			var rotation_fix : Transform = rest_transform.inverse() * Transform(roll_global_offsets[i]).inverse() * rest_transform
			
			roll_local_offsets[child_id] *= rotation_fix
		
	# Reset skeleton and skin before applying the rolls and fixing the bindposes
	p_skins = reset_skeleton_and_bind_pose(p_skeleton, p_skins, p_default_skins, bone_pose_array)
	
	if APPLY_AS_REST:
		for i in range(0, p_skeleton.get_bone_count()):
			p_skeleton.set_bone_rest(i, rest_transform_local_offsets[i] * t_pose_transform_local_offsets[i] * rotation_fix_transform_local_offsets[i])
	else:
		for i in range(0, p_skeleton.get_bone_count()):
			p_skeleton.set_bone_pose(i, bone_pose_array[i] * t_pose_transform_local_offsets[i] * rotation_fix_transform_local_offsets[i])
			
	for i in range(0, p_skins.size()):
		if p_skins[i]:
			for j in range(0, p_skins[i].get_bind_count()):
				p_skins[i] = apply_local_transform_to_bind_pose(j, p_skeleton, p_skins[i], rest_transform_local_offsets, roll_local_offsets)
		
	return p_skins

static func fix_rotations(p_root: Spatial, p_skeleton: Skeleton, p_humanoid_data: humanoid_data_const, p_t_pose_local_offsets: Array) -> int:
		
	print("---Running RotationFixer---")
	
	var err: int = avatar_callback_const.generic_error_check(p_root, p_skeleton)
	if err != avatar_callback_const.AVATAR_OK:
		return err
	
	var mesh_instances: Array = find_mesh_instances_for_skeleton(p_root, p_root._skeleton_node, [])
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
			
	skins = fix_rotations_internal(p_root, p_root._skeleton_node, p_root.humanoid_data, skins, [], p_t_pose_local_offsets)
	
	if skins.size() == mesh_instances.size():
		for i in range(0, mesh_instances.size()):
			mesh_instances[i].skin = skins[i]
	else:
		return avatar_callback_const.SKIN_MESH_INSTANCE_SIZE_MISMATCH
		
	return avatar_callback_const.AVATAR_OK
