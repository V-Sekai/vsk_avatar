extends Node

const hand_pose_const = preload("hand_pose.gd")

static func get_transform_for_humanoid_bone(
	p_skeleton: Skeleton3D,
	p_humanoid_data: HumanoidData,
	p_humanoid_bone_name: String) -> Transform3D:
	
	var humanoid_bone_name: String = p_humanoid_data.get(p_humanoid_bone_name)
	var bone_id: int = p_skeleton.find_bone(humanoid_bone_name)
	if bone_id != -1:
		return p_skeleton.get_bone_pose(bone_id)
	
	return Transform3D()

static func generate_hand_pose_from_skeleton(
	p_skeleton: Skeleton3D,
	p_humanoid_data: HumanoidData,
	p_right_hand: bool) -> RefCounted:
	
	var hand_pose: RefCounted = hand_pose_const.new()
	
	if p_right_hand:
		hand_pose.thumb_proximal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"thumb_proximal_right_bone_name")
		hand_pose.thumb_intermediate = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"thumb_intermediate_right_bone_name")
		hand_pose.thumb_distal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"thumb_distal_right_bone_name")
			
		hand_pose.index_proximal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"index_proximal_right_bone_name")
		hand_pose.index_intermediate = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"index_intermediate_right_bone_name")
		hand_pose.index_distal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"index_distal_right_bone_name")
			
		hand_pose.middle_proximal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"middle_proximal_right_bone_name")
		hand_pose.middle_intermediate = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"middle_intermediate_right_bone_name")
		hand_pose.middle_distal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"middle_distal_right_bone_name")
			
		hand_pose.ring_proximal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"ring_proximal_right_bone_name")
		hand_pose.ring_intermediate = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"ring_intermediate_right_bone_name")
		hand_pose.ring_distal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"ring_distal_right_bone_name")
		
		hand_pose.little_proximal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"little_proximal_right_bone_name")
		hand_pose.little_intermediate = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"little_intermediate_right_bone_name")
		hand_pose.little_distal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"little_distal_right_bone_name")
	else:
		hand_pose.thumb_proximal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"thumb_proximal_left_bone_name")
		hand_pose.thumb_intermediate = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"thumb_intermediate_left_bone_name")
		hand_pose.thumb_distal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"thumb_distal_left_bone_name")
			
		hand_pose.index_proximal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"index_proximal_left_bone_name")
		hand_pose.index_intermediate = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"index_intermediate_left_bone_name")
		hand_pose.index_distal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"index_distal_left_bone_name")
			
		hand_pose.middle_proximal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"middle_proximal_left_bone_name")
		hand_pose.middle_intermediate = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"middle_intermediate_left_bone_name")
		hand_pose.middle_distal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"middle_distal_left_bone_name")
			
		hand_pose.ring_proximal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"ring_proximal_left_bone_name")
		hand_pose.ring_intermediate = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"ring_intermediate_left_bone_name")
		hand_pose.ring_distal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"ring_distal_left_bone_name")
		
		hand_pose.little_proximal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"little_proximal_left_bone_name")
		hand_pose.little_intermediate = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"little_intermediate_left_bone_name")
		hand_pose.little_distal = get_transform_for_humanoid_bone(
			p_skeleton,
			p_humanoid_data,
			"little_distal_left_bone_name")
	
	return hand_pose
