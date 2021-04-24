extends Node

# Hand Animation
const default_avatar_tree_const = preload("animation/default_avatar_tree.tres")

const hand_pose_const = preload("hand_pose.gd")

const hand_pose_default_const = preload("hand_poses/hand_pose_default_pose.tres")
const hand_pose_fist_const = preload("hand_poses/hand_pose_fist.tres")
const hand_pose_gun_const = preload("hand_poses/hand_pose_gun.tres")
const hand_pose_neutral_const = preload("hand_poses/hand_pose_neutral.tres")
const hand_pose_ok_sign_const = preload("hand_poses/hand_pose_ok_sign.tres")
const hand_pose_open_const = preload("hand_poses/hand_pose_open.tres")
const hand_pose_point_const = preload("hand_poses/hand_pose_point.tres")
const hand_pose_thumbs_up_const = preload("hand_poses/hand_pose_thumbs_up.tres")
const hand_pose_victory_const = preload("hand_poses/hand_pose_victory.tres")

static func create_pose_track_for_humanoid_bone(
	p_animation: Animation,
	p_base_path: String,
	p_skeleton: Skeleton,
	p_humanoid_data: HumanoidData,
	p_humanoid_bone_name: String,
	p_transform: Transform) -> Animation:
	
	var bone_name: String = p_humanoid_data[p_humanoid_bone_name]
	var bone_index: int = p_skeleton.find_bone(bone_name)
	if bone_index == -1:
		return p_animation
	
	var track_index = p_animation.add_track(Animation.TYPE_TRANSFORM)
	
	p_animation.track_set_path(track_index, p_base_path + ":" + bone_name)
	p_animation.transform_track_insert_key(
		track_index,
		0.0,
		Vector3(),
		p_transform.basis.get_rotation_quat(),
		Vector3(1.0, 1.0, 1.0))
		
	p_animation.track_set_enabled(track_index, true)
	p_animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
	p_animation.track_set_interpolation_loop_wrap(track_index, true)

	return p_animation
	
static func create_animation_from_hand_pose(
	p_root_node: Node,
	p_skeleton: Skeleton,
	p_humanoid_data: HumanoidData,
	p_hand_pose: hand_pose_const) -> Animation:
		
	var animation: Animation = Animation.new()
	animation.length = 0.001
	for side in ["left", "right"]:
		for digit in ["thumb", "index", "middle", "ring", "little"]:
			for joint in ["proximal", "intermediate", "distal"]:
				
				var transform: Transform = Transform()
				if side == "left":
					transform = p_hand_pose.get(
						"%s_%s" % [digit, joint])
				else:
					# TODO: clean this up
					var euler: Vector3 = p_hand_pose.get(
						"%s_%s" % [digit, joint]).basis.get_euler()
					
					euler.z = -euler.z
					euler.y = -euler.y
					
					transform = Transform(Basis(euler), Vector3())
				
				animation = create_pose_track_for_humanoid_bone(
					animation,
					p_root_node.get_path_to(p_skeleton),
					p_skeleton,
					p_humanoid_data,
					"%s_%s_%s_bone_name" % [digit, joint, side],
					transform
					)
	return animation
					
static func setup_animation_from_hand_pose(
	p_animation_player: AnimationPlayer,
	p_root_node: Node,
	p_skeleton: Skeleton,
	p_humanoid_data: HumanoidData,
	p_hand_pose_name: String,
	p_hand_pose: hand_pose_const) -> void:
		
	var animation: Animation = create_animation_from_hand_pose(
		p_root_node,
		p_skeleton,
		p_humanoid_data,
		p_hand_pose)
	
	ResourceSaver.save("res://anim_dump/%s.tres" % p_hand_pose_name, animation)
		
	p_animation_player.add_animation(
		p_hand_pose_name,
		animation)
			
static func setup_animation_from_hand_pose_dictionary(
	p_animation_player: AnimationPlayer,
	p_root_node: Node,
	p_skeleton: Skeleton,
	p_humanoid_data: HumanoidData,
	p_pose_dictionary: Dictionary) -> void:
	
	for key in p_pose_dictionary:
		setup_animation_from_hand_pose(
			p_animation_player,
			p_root_node,
			p_skeleton,
			p_humanoid_data,
			key,
			p_pose_dictionary[key])
	
static func setup_default_hand_animations(
	p_animation_player: AnimationPlayer,
	p_root_node: Node,
	p_skeleton: Skeleton,
	p_humanoid_data: HumanoidData) -> AnimationPlayer:
	#
	setup_animation_from_hand_pose_dictionary(
		p_animation_player,
		p_root_node,
		p_skeleton,
		p_humanoid_data,
		{
			"DefaultPose":hand_pose_default_const,
			"Neutral":hand_pose_neutral_const,
			"Fist":hand_pose_fist_const,
			"Point":hand_pose_point_const,
			"Gun":hand_pose_gun_const,
			"OKSign":hand_pose_ok_sign_const,
			"ThumbsUp":hand_pose_thumbs_up_const,
			"Victory":hand_pose_victory_const,
			"Open":hand_pose_open_const
		}
	)
	
	return p_animation_player
	
static func setup_animation_tree_hand_blend_tree(
	p_root: Node,
	p_animation_tree: AnimationTree,
	p_animation_player: AnimationPlayer,
	p_skeleton: Skeleton,
	p_humanoid_data: HumanoidData) -> AnimationTree:
		
	p_animation_tree.anim_player = p_animation_tree.get_path_to(p_animation_player)
	p_animation_tree.tree_root = default_avatar_tree_const
	p_animation_tree.process_mode = AnimationTree.ANIMATION_PROCESS_MANUAL
	p_animation_tree.active = true
	
	var left_hand_blend: AnimationNode = p_animation_tree.tree_root.get_node("LeftHandBlend")
	var right_hand_blend: AnimationNode = p_animation_tree.tree_root.get_node("RightHandBlend")
	
	left_hand_blend.filter_enabled = true
	right_hand_blend.filter_enabled = true
	
	var base_path: String = p_root.get_path_to(p_skeleton)
	
	for digit in ["thumb", "index", "middle", "ring", "little"]:
		for joint in ["proximal", "intermediate", "distal"]:
			# Left
			var left_bone_name: String = p_humanoid_data["%s_%s_left_bone_name" % [digit, joint]]
			var left_bone_index: int = p_skeleton.find_bone(left_bone_name)
			if left_bone_index != -1:
				var filter_path: String = base_path + ":" + left_bone_name
				left_hand_blend.set_filter_path(filter_path, true)
			# Right
			var right_bone_name: String = p_humanoid_data["%s_%s_right_bone_name" % [digit, joint]]
			var right_bone_index: int = p_skeleton.find_bone(right_bone_name)
			if right_bone_index != -1:
				var filter_path: String = base_path + ":" + right_bone_name
				right_hand_blend.set_filter_path(filter_path, true)
				
	return p_animation_tree
