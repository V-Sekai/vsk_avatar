extends Node
tool

const humanoid_data_const = preload("humanoid_data.gd")

const HIP_NAMES = PoolStringArray(["hips", "hip", "pelvis"])
const SPINE_NAMES = PoolStringArray(["spine"])
const CHEST_NAMES = PoolStringArray(["chest"])
const NECK_NAMES = PoolStringArray(["neck", "collar"])
const HEAD_NAMES = PoolStringArray(["head"])
const EYE_NAMES = PoolStringArray(["eye"])

const UPPER_NAMES = PoolStringArray(["up", "upper"])
const LOWER_NAMES = PoolStringArray(["lower"])

const SHOULDER_NAMES = PoolStringArray(["shoulder", "clavicle"])
const ARM_NAMES = PoolStringArray(["arm"])
const UPPER_ARM_NAMES = PoolStringArray(["upperarm", "uparm", "bicep"])
const LOWER_ARM_NAMES = PoolStringArray(["lowerarm", "forearm", "elbow"])

const LEG_NAMES = PoolStringArray(["leg"])
const UPPER_LEG_NAMES = PoolStringArray(["upleg", "upperleg", "thigh"])
const LOWER_LEG_NAMES = PoolStringArray(["knee", "calf"])

const FOOT_NAMES = PoolStringArray(["foot", "ankle"])
const TOE_NAMES = PoolStringArray(["toe"])

const THUMB_NAMES = PoolStringArray(["thumb"])
const INDEX_FINGER_NAMES = PoolStringArray(["index"])
const MIDDLE_FINGER_NAMES = PoolStringArray(["middle"])
const RING_FINGER_NAMES = PoolStringArray(["ring"])
const PINKY_FINGER_NAMES = PoolStringArray(["pinky"])

const TWIST_BONE_NAME = PoolStringArray(["twist", "roll"])

static func get_sanitisied_bone_name_list(p_skeleton: Skeleton) -> PoolStringArray:
	var sanitised_names: PoolStringArray = PoolStringArray()
	for i in range(0, p_skeleton.get_bone_count()):
		sanitised_names.push_back(p_skeleton.get_bone_name(i))

	return sanitised_names

static func get_bone_children_ids(
	p_skeleton: Skeleton, p_id: int, p_children: PoolIntArray = PoolIntArray()
) -> PoolIntArray:
	var parent_id: int = p_skeleton.get_bone_parent(p_id)
	if parent_id != -1:
		p_children.push_back(parent_id)
		p_children = get_bone_children_ids(p_skeleton, parent_id, p_children)

	return p_children

class BoneInfo extends Reference:
	var bone_parent: int = -1
	var bone_name: String = ""
	var bone_length: float = 0.0
	var bone_direction: Vector3 = Vector3()

func gather_bone_info(p_skeleton: Skeleton) -> humanoid_data_const:
	var humanoid_data: humanoid_data_const = humanoid_data_const.new()
	var bone_info_list: Array = []

	for i in range(0, p_skeleton.get_bone_count()):
		var bone_info: BoneInfo = BoneInfo.new()
		
		bone_info.bone_name = p_skeleton.get_bone_name(i)
		bone_info.bone_parent = p_skeleton.get_bone_parent(i)
		
		if bone_info.bone_parent != -1:
			bone_info.bone_length = p_skeleton.get_bone_rest(i).origin.distance_to(Vector3())
			bone_info.bone_direction = Vector3().direction_to(p_skeleton.get_bone_rest(i).origin)
			
		
		bone_info.push_back(bone_info)

	return humanoid_data
