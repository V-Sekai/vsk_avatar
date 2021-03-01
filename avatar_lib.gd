extends Node

const avatar_constants_const = preload("avatar_constants.gd")
const bone_lib_const = preload("bone_lib.gd")

static func find_mesh_instances_for_avatar_skeleton(p_node: Node, p_skeleton: Skeleton, p_valid_mesh_instances: Array) -> Array:
	if p_skeleton and p_node is MeshInstance:
		var skeleton: Node = p_node.get_node_or_null(p_node.skeleton)
		if skeleton == p_skeleton:
			p_valid_mesh_instances.push_back(p_node)
			
	for child in p_node.get_children():
		p_valid_mesh_instances = find_mesh_instances_for_avatar_skeleton(child, p_skeleton, p_valid_mesh_instances)
	
	return p_valid_mesh_instances

static func get_chain(
	p_skeleton: Skeleton,
	p_humanoid_data: HumanoidData,
	p_side: int,
	p_start_name: String,
	p_end_name: String,
	p_alt_start_name: String) -> PoolIntArray:
		
		
	var direction_name : String = ""
	if p_side == avatar_constants_const.SIDE_LEFT or p_side == avatar_constants_const.SIDE_RIGHT:
		direction_name = avatar_constants_const.get_name_for_side(p_side) + "_"
	
	var alt_start_bone_name : String = ""
	var start_bone_name : String = ""
	var end_bone_name : String = ""
	
	if p_alt_start_name:
		alt_start_bone_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(\
		p_skeleton, p_humanoid_data, "%s_%sbone_name" % [p_alt_start_name, direction_name])
	if p_start_name:
		start_bone_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(\
		p_skeleton, p_humanoid_data, "%s_%sbone_name" % [p_start_name, direction_name])
	if p_end_name:
		end_bone_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(\
		p_skeleton, p_humanoid_data, "%s_%sbone_name" % [p_end_name, direction_name])
	
	if start_bone_name == "":
		start_bone_name = alt_start_bone_name
		
	if start_bone_name == "" or end_bone_name == "":
		return PoolIntArray()

	var start_id : int = p_skeleton.find_bone(start_bone_name)
	var end_id : int = p_skeleton.find_bone(end_bone_name)
	
	if start_id == -1 or end_id == -1:
		return PoolIntArray()
	
	return bone_lib_const.get_full_bone_chain(p_skeleton, start_id, end_id)

static func find_bone_in_chain_array(p_bone_id: int, p_chains: Array) -> Dictionary:
	for chain in p_chains:
		var index: int = chain.find(p_bone_id)
		if index != -1:
			return {"chain":chain, "index":index}
			
	return {}

static func get_arm_chain(p_skeleton: Skeleton, p_humanoid_data: HumanoidData, p_side: int) -> PoolIntArray:
	return get_chain(p_skeleton, p_humanoid_data, p_side, "shoulder", "hand", "upper_arm")
	
static func get_leg_chain(p_skeleton: Skeleton, p_humanoid_data: HumanoidData, p_side: int) -> PoolIntArray:
	return get_chain(p_skeleton, p_humanoid_data, p_side, "thigh", "shin", "")
	
static func get_full_spine_chain(p_skeleton: Skeleton, p_humanoid_data: HumanoidData) -> PoolIntArray:
	return get_chain(p_skeleton, p_humanoid_data, avatar_constants_const.SIDE_CENTER, "hips", "head", "")
	
static func get_digit_chain(p_skeleton: Skeleton, p_humanoid_data: HumanoidData, p_side: int, p_digit) -> PoolIntArray:
	return get_chain(p_skeleton, p_humanoid_data, p_side,\
	"%s_%s" % [
		avatar_constants_const.get_name_for_digit(p_digit),
		avatar_constants_const.get_name_for_digit_joint(avatar_constants_const.DIGIT_JOINT_PROXIMAL)
	],
	"%s_%s" % [
		avatar_constants_const.get_name_for_digit(p_digit),
		avatar_constants_const.get_name_for_digit_joint(avatar_constants_const.DIGIT_JOINT_DISTAL)
	],
	"")
