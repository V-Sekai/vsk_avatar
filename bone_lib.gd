extends RefCounted

const node_util_const = preload("res://addons/gd_util/node_util.gd")
const humanoid_data_const = preload("res://addons/vsk_avatar/humanoid_data.gd")

const NO_BONE = -1

static func get_bone_global_transform(p_id: int, p_skeleton: Skeleton3D, p_local_transform_array: Array) -> Transform3D:
	var return_transform: Transform3D = Transform3D()
	var parent_id: int = p_skeleton.get_bone_parent(p_id)
	if parent_id != -1:
		return_transform = get_bone_global_transform(parent_id, p_skeleton, p_local_transform_array)

	for transform in p_local_transform_array:
		return_transform *= transform[p_id]

	return return_transform

static func get_bone_global_rest_transform(p_id: int, p_skeleton: Skeleton3D) -> Transform3D:
	var rest_local_transforms: Array = []
	for i in range(0, p_skeleton.get_bone_count()):
		rest_local_transforms.push_back(p_skeleton.get_bone_rest(i))

	return get_bone_global_transform(p_id, p_skeleton, [rest_local_transforms])

static func get_full_bone_chain(p_skeleton: Skeleton3D, p_first: int, p_last: int) -> PackedInt32Array:
	var bone_chain: PackedInt32Array = get_bone_chain(p_skeleton, p_first, p_last)
	bone_chain.push_back(p_last)

	return bone_chain

static func get_bone_chain(p_skeleton: Skeleton3D, p_first: int, p_last: int) -> PackedInt32Array:
	var bone_chain: Array = []

	if p_first != -1 and p_last != -1:
		var current_bone_index: int = p_last

		while 1:
			current_bone_index = p_skeleton.get_bone_parent(current_bone_index)
			bone_chain.push_front(current_bone_index)
			match current_bone_index:
				p_first:
					break
				-1:
					return PackedInt32Array()

	return PackedInt32Array(bone_chain)

static func get_internal_bone_name_for_humanoid_bone(
	p_skeleton: Skeleton3D, p_humanoid_data: humanoid_data_const, p_bone_name: String
) -> String:
	if p_skeleton and p_humanoid_data:
		var internal_bone_name: String = p_humanoid_data.get(p_bone_name)
		return internal_bone_name

	return ""

static func get_bone_id_for_humanoid_bone(
	p_skeleton: Skeleton3D, p_humanoid_data: humanoid_data_const, p_bone_name: String
) -> int:
	if p_skeleton and p_humanoid_data:
		var internal_bone_name: String = get_internal_bone_name_for_humanoid_bone(
			p_skeleton, p_humanoid_data, p_bone_name
		)
		return p_skeleton.find_bone(internal_bone_name)

	return -1

static func is_bone_parent_of(p_skeleton: Skeleton3D, p_parent_id: int, p_child_id: int) -> bool:
	var p: int = p_skeleton.get_bone_parent(p_child_id)
	while (p != -1):
		if (p == p_parent_id):
			return true
		p = p_skeleton.get_bone_parent(p)
		
	return false
	
static func is_bone_parent_of_or_self(p_skeleton: Skeleton3D, p_parent_id: int, p_child_id: int) -> bool:
	if p_parent_id == p_child_id:
		return true
		
	return is_bone_parent_of(p_skeleton, p_parent_id, p_child_id)

static func rename_skeleton_to_humanoid_bones(
	p_skeleton: Skeleton3D, p_humanoid_data: humanoid_data_const, p_skins: Array
) -> bool:
	if p_skeleton == null or p_humanoid_data == null:
		return false

	var bone_count: int = p_skeleton.get_bone_count()

	var original_bone_names: Array = []
	var bone_names: Array = []
	var bone_rests: Array = []
	var bone_parents: Array = []

	# Get all the data from the original skeleton
	for i in range(0, bone_count):
		original_bone_names.push_back(p_skeleton.get_bone_name(i))
		bone_names.push_back(p_skeleton.get_bone_name(i))
		bone_rests.push_back(p_skeleton.get_bone_rest(i))
		bone_parents.push_back(p_skeleton.get_bone_parent(i))

	# Rename all the bones with the humanoid_mappings
	for name in humanoid_data_const.skeleton_mappings:
		var bone_id: int = get_bone_id_for_humanoid_bone(
			p_skeleton, p_humanoid_data, "%s_bone_name" % name
		)
		if bone_id != -1:
			bone_names[bone_id] = name

		p_humanoid_data.set("%s_bone_name" % name, name)

	# Destroy the old skeleton and replace it with the new data
	p_skeleton.clear_bones()
	for i in range(0, bone_count):
		p_skeleton.add_bone(bone_names[i])
		p_skeleton.set_bone_parent(i, bone_parents[i])
		p_skeleton.set_bone_rest(i, bone_rests[i])

	# Update the names for the skins too
	for skin in p_skins:
		for i in range(0, skin.get_bind_count()):
			var bind_name: String = skin.get_bind_name(i)
			for j in range(0, original_bone_names.size()):
				if bind_name == original_bone_names[j]:
					skin.set_bind_name(i, bone_names[j])

	return true
