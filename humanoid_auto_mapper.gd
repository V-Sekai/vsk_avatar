@tool
extends Node

const humanoid_data_const = preload("humanoid_data.gd")

const HIP_NAMES = PackedStringArray(["hips", "hip", "pelvis"])
const SPINE_NAMES = PackedStringArray(["spine"])
const CHEST_NAMES = PackedStringArray(["chest"])
const NECK_NAMES = PackedStringArray(["neck", "collar"])
const HEAD_NAMES = PackedStringArray(["head"])
const EYE_NAMES = PackedStringArray(["eye"])

const UPPER_NAMES = PackedStringArray(["up", "upper"])
const LOWER_NAMES = PackedStringArray(["lower"])

const SHOULDER_NAMES = PackedStringArray(["shoulder", "clavicle"])
const ARM_NAMES = PackedStringArray(["arm"])
const UPPER_ARM_NAMES = PackedStringArray(["upperarm", "uparm", "bicep"])
const LOWER_ARM_NAMES = PackedStringArray(["lowerarm", "forearm", "elbow"])

const LEG_NAMES = PackedStringArray(["leg"])
const UPPER_LEG_NAMES = PackedStringArray(["upleg", "upperleg", "thigh"])
const LOWER_LEG_NAMES = PackedStringArray(["knee", "calf"])

const FOOT_NAMES = PackedStringArray(["foot", "ankle"])
const TOE_NAMES = PackedStringArray(["toe"])

const THUMB_NAMES = PackedStringArray(["thumb"])
const INDEX_FINGER_NAMES = PackedStringArray(["index"])
const MIDDLE_FINGER_NAMES = PackedStringArray(["middle"])
const RING_FINGER_NAMES = PackedStringArray(["ring"])
const PINKY_FINGER_NAMES = PackedStringArray(["pinky"])

const TWIST_BONE_NAME = PackedStringArray(["twist", "roll"])

static func get_sanitisied_bone_name_list(p_skeleton: Skeleton3D) -> PackedStringArray:
	var sanitised_names: PackedStringArray = PackedStringArray()
	for i in range(0, p_skeleton.get_bone_count()):
		sanitised_names.push_back(p_skeleton.get_bone_name(i))

	return sanitised_names

static func get_bone_children_ids(
	p_skeleton: Skeleton3D, p_id: int, p_children: PackedInt32Array = PackedInt32Array()
) -> PackedInt32Array:
	var parent_id: int = p_skeleton.get_bone_parent(p_id)
	if parent_id != -1:
		p_children.push_back(parent_id)
		p_children = get_bone_children_ids(p_skeleton, parent_id, p_children)

	return p_children

class BoneInfo extends RefCounted:
	var bone_parent: int = -1
	var bone_name: String = ""
	var bone_length: float = 0.0
	var bone_direction: Vector3 = Vector3()

func gather_bone_info(p_skeleton: Skeleton3D) -> humanoid_data_const:
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
