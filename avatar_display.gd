@tool
extends Node3D

const node_util_const = preload("res://addons/gd_util/node_util.gd")

# const player_camera_controller_const = preload("res://addons/actor/player_camera_controller.gd")

const avatar_definition_const = preload("vsk_avatar_definition.gd")
const avatar_definition_runtime_const = preload("vsk_avatar_definition_runtime.gd")

const humanoid_data_const = preload("humanoid_data.gd")
# const gizmo_reference_const = preload("gizmo_reference.tscn")

const attachment_point_3d_const = preload("res://addons/entity_manager/attachment_point_3d.gd")
const vr_constants_const = preload("res://addons/sar1_vr_manager/vr_constants.gd")

var avatar_setup_const = load("res://addons/vsk_avatar/avatar_setup.gd")

signal avatar_setup_complete
signal avatar_setup_failed

var simulation_logic: Node = null

# Ugly workaround for limitations of the IK system
# Deals with the fact that shrinking the head and then
# writing out transforms call result in determinant
# errors
var saved_head_transform: Transform3D = Transform3D()

var use_wristspan_ratio: bool = false
var avatar_eye_height: float = 0.0
var avatar_wristspan: float = 0.0
var height_offset: float = 0.0

var humanoid_data: RefCounted = null # humanoid_data_const
var avatar_skeleton: Skeleton3D = null
var voice_player: Node = null

# The transform of the voice player relative the head bone
var relative_mouth_transform: Transform3D = Transform3D()

var head_id: int = bone_lib_const.NO_BONE
var hip_id: int = bone_lib_const.NO_BONE

var left_hand_id: int = bone_lib_const.NO_BONE
var right_hand_id: int = bone_lib_const.NO_BONE
var left_lower_arm_id: int = bone_lib_const.NO_BONE
var right_lower_arm_id: int = bone_lib_const.NO_BONE
var left_upper_arm_id: int = bone_lib_const.NO_BONE
var right_upper_arm_id: int = bone_lib_const.NO_BONE

var left_foot_id: int = bone_lib_const.NO_BONE
var right_foot_id: int = bone_lib_const.NO_BONE
var left_lower_leg_id: int = bone_lib_const.NO_BONE
var right_lower_leg_id: int = bone_lib_const.NO_BONE
var left_upper_leg_id: int = bone_lib_const.NO_BONE
var right_upper_leg_id: int = bone_lib_const.NO_BONE


var head_bone_attachment: BoneAttachment3D = null
var left_hand_bone_attachment: BoneAttachment3D = null
var right_hand_bone_attachment: BoneAttachment3D = null

enum shrink_enum {
	DETERMINED_BY_VIEW = 0,
	SHRINK,
	UNSHRINK
}

@export_enum("Determined by View", "Shrink", "Unshrink")
var shrink_mode : int
@export var default_avatar_height : float = 1.8
@export var _ren_ik_path: NodePath = NodePath()
@export var _ik_space_path: NodePath = NodePath()
@export var player_camera_controller_path: NodePath = NodePath()
@export var player_hand_controller_path: NodePath = NodePath()
@export var player_input_path: NodePath = NodePath()
@export var voice_player_path: NodePath = NodePath()
 # (NodePath)
var _player_input_node: Node = null
var _ik_space: Node = null
var _player_camera_controller: Node = null

var avatar_node: Node3D = null

const avatar_default_driver_const = preload("avatar_default_driver.gd")
const bone_lib_const = preload("res://addons/vsk_avatar/bone_lib.gd")

const VISUALISE_ATTACHMENTS = false

const AVATAR_BASIS = Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0))
# This is totally abitrary, please find a better way to calculate this
const AVATAR_LOWER_DISTANCE = 0.05


func clear_avatar() -> void:
	if avatar_node:
		setup_bone_attachments(null, null)
		avatar_node.queue_free()
		avatar_node.get_parent().remove_child(avatar_node)
		avatar_node = null

		var ren_ik: Node = get_node_or_null(_ren_ik_path)
		if ren_ik:
			clear_ik_bone_assignments(ren_ik)

func _on_avatar_cleared():
	clear_avatar()

func _avatar_ready(p_packed_scene: PackedScene) -> void:
	if is_inside_tree():
		if p_packed_scene:
			clear_avatar()

			setup_avatar_instantiate(p_packed_scene.instantiate())

func _update_voice_player() -> void:
	if voice_player:
		if voice_player.get_parent() != head_bone_attachment:
			if voice_player.is_inside_tree():
				voice_player.get_parent().remove_child(voice_player)
			if head_bone_attachment != null:
				head_bone_attachment.add_child(voice_player)
		voice_player.transform = relative_mouth_transform * Transform3D().rotated(Vector3(0.0, 1.0, 0.0), PI)


func setup_bone_attachments(p_humanoid_data: RefCounted, p_skeleton: Skeleton3D) -> void: # humanoid_data_const
	if p_humanoid_data == null:
		return
	if p_skeleton == null:
		return
	head_bone_attachment.get_parent().remove_child(head_bone_attachment)
	left_hand_bone_attachment.get_parent().remove_child(left_hand_bone_attachment)
	right_hand_bone_attachment.get_parent().remove_child(right_hand_bone_attachment)

	if p_skeleton and p_humanoid_data:
		var head_bone_id: int = humanoid_data.find_skeleton_bone_for_humanoid_bone(
			p_skeleton, humanoid_data_const.head)
		var left_bone_id: int = humanoid_data.find_skeleton_bone_for_humanoid_bone(
			p_skeleton, humanoid_data_const.hand_left)
		var right_bone_id: int = humanoid_data.find_skeleton_bone_for_humanoid_bone(
			p_skeleton, humanoid_data_const.hand_right)

		if head_bone_id != bone_lib_const.NO_BONE:
			p_skeleton.add_child(head_bone_attachment)
			head_bone_attachment.bone_name = p_humanoid_data.head_bone_name
		else:
			add_child(head_bone_attachment)
		if left_bone_id != bone_lib_const.NO_BONE:
			p_skeleton.add_child(left_hand_bone_attachment)
			left_hand_bone_attachment.bone_name = p_humanoid_data.hand_left_bone_name
		else:
			add_child(left_hand_bone_attachment)
		if right_bone_id != bone_lib_const.NO_BONE:
			p_skeleton.add_child(right_hand_bone_attachment)
			right_hand_bone_attachment.bone_name = p_humanoid_data.hand_right_bone_name
		else:
			add_child(right_hand_bone_attachment)
	else:
		add_child(head_bone_attachment)
		add_child(left_hand_bone_attachment)
		add_child(right_hand_bone_attachment)


func create_bone_attachments() -> void:
	head_bone_attachment = BoneAttachment3D.new()
	left_hand_bone_attachment = BoneAttachment3D.new()
	right_hand_bone_attachment = BoneAttachment3D.new()

	head_bone_attachment.set_name("HeadAttachmentPoint")
	left_hand_bone_attachment.set_name("LeftHandAttachmentPoint")
	right_hand_bone_attachment.set_name("RightHandAttachmentPoint")

	head_bone_attachment.set_script(attachment_point_3d_const)
	left_hand_bone_attachment.set_script(attachment_point_3d_const)
	right_hand_bone_attachment.set_script(attachment_point_3d_const)

	var entity_node: Node3D = simulation_logic.get_entity_node()
	if entity_node == null:
		printerr("Entity node could not be found!")

	head_bone_attachment.set_entity(entity_node)
	left_hand_bone_attachment.set_entity(entity_node)
	right_hand_bone_attachment.set_entity(entity_node)

	add_child(head_bone_attachment)
	add_child(left_hand_bone_attachment)
	add_child(right_hand_bone_attachment)

	if VISUALISE_ATTACHMENTS:
		var gizmo_reference_scene = load("res://addons/vsk_avatar/gizmo_reference.tscn")
		head_bone_attachment.add_child(gizmo_reference_scene.instantiate())
		left_hand_bone_attachment.add_child(gizmo_reference_scene.instantiate())
		right_hand_bone_attachment.add_child(gizmo_reference_scene.instantiate())

func assign_ik_bone_assignments(
	p_ren_ik_node: Node, p_skeleton: Skeleton3D, p_humanoid_data: HumanoidData
) -> void:
	if str(p_ren_ik_node.get_class()) != "RenIK":
		push_warning("RenIK is " + str(p_ren_ik_node.get_class()) + " not RenIK")
		return
	if !p_humanoid_data:
		head_id = -1
		hip_id = -1

		left_hand_id = -1
		right_hand_id = -1

		left_lower_arm_id = -1
		right_lower_arm_id = -1
		left_upper_arm_id = -1
		right_upper_arm_id = -1

		left_foot_id = -1
		right_foot_id = -1

		left_lower_leg_id = -1
		right_lower_leg_id = -1
		left_upper_leg_id = -1
		right_upper_leg_id = -1
	else:
		# Spine
		head_id = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.head)
		hip_id = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.hips)

		# Arm
		left_hand_id = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.hand_left)
		right_hand_id = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.hand_right)

		left_lower_arm_id = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.forearm_left)
		right_lower_arm_id = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.forearm_right)

		left_upper_arm_id = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.upper_arm_left)
		right_upper_arm_id = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.upper_arm_right)

		# Leg
		left_foot_id = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.foot_left)
		right_foot_id = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.foot_right)

		left_lower_leg_id = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.shin_left)
		right_lower_leg_id = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.shin_right)

		left_upper_leg_id = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.thigh_left)
		right_upper_leg_id = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.thigh_right)

	p_ren_ik_node.set_head_bone(head_id)
	p_ren_ik_node.set_hip_bone(hip_id)

	p_ren_ik_node.set_hand_left_bone(left_hand_id)
	p_ren_ik_node.set_hand_right_bone(right_hand_id)
	p_ren_ik_node.set_lower_arm_left_bone(left_lower_arm_id)
	p_ren_ik_node.set_lower_arm_right_bone(right_lower_arm_id)
	p_ren_ik_node.set_upper_arm_left_bone(left_upper_arm_id)
	p_ren_ik_node.set_upper_arm_right_bone(right_upper_arm_id)
	#
	p_ren_ik_node.set_foot_left_bone(left_foot_id)
	p_ren_ik_node.set_foot_right_bone(right_foot_id)
	p_ren_ik_node.set_lower_leg_left_bone(left_lower_leg_id)
	p_ren_ik_node.set_lower_leg_right_bone(right_lower_leg_id)
	p_ren_ik_node.set_upper_leg_left_bone(left_upper_leg_id)
	p_ren_ik_node.set_upper_leg_right_bone(right_upper_leg_id)

func clear_ik_bone_assignments(p_ren_ik_node: Node) -> void:
	if str(p_ren_ik_node.get_class()) != "RenIK":
		push_warning("RenIK is " + str(p_ren_ik_node.get_class()) + " not RenIK")
		return
	p_ren_ik_node.set_head_bone(bone_lib_const.NO_BONE)
	p_ren_ik_node.set_hip_bone(bone_lib_const.NO_BONE)

	p_ren_ik_node.set_hand_left_bone(bone_lib_const.NO_BONE)
	p_ren_ik_node.set_hand_right_bone(bone_lib_const.NO_BONE)
	p_ren_ik_node.set_lower_arm_left_bone(bone_lib_const.NO_BONE)
	p_ren_ik_node.set_lower_arm_right_bone(bone_lib_const.NO_BONE)
	p_ren_ik_node.set_upper_arm_left_bone(bone_lib_const.NO_BONE)
	p_ren_ik_node.set_upper_arm_right_bone(bone_lib_const.NO_BONE)

	p_ren_ik_node.set_foot_left_bone(bone_lib_const.NO_BONE)
	p_ren_ik_node.set_foot_right_bone(bone_lib_const.NO_BONE)
	p_ren_ik_node.set_lower_leg_left_bone(bone_lib_const.NO_BONE)
	p_ren_ik_node.set_lower_leg_right_bone(bone_lib_const.NO_BONE)
	p_ren_ik_node.set_upper_leg_left_bone(bone_lib_const.NO_BONE)
	p_ren_ik_node.set_upper_leg_right_bone(bone_lib_const.NO_BONE)

func _xr_mode_changed() -> void:
	calculate_proportions()

func _proportions_changed() -> void:
	calculate_proportions()

func calculate_proportions() -> void:
	if VRManager.is_xr_active():
		var player_height = VRManager.vr_user_preferences.custom_player_height
		var origin_height_scale_offset: float = (
			(avatar_eye_height + vr_constants_const.EYE_TO_TOP_OF_HEAD)
			/ VRManager.vr_user_preferences.custom_player_height
		)
		var player_wrist_length = (
			VRManager.vr_user_preferences.custom_player_height
			* VRManager.vr_user_preferences.custom_player_armspan_to_height_ratio
			* vr_constants_const.ARMSPAN_WRIST_SPAN_CONVERSION
		)
		var origin_wrist_scale_offset: float = avatar_wristspan / player_wrist_length

		VRManager.set_origin_world_scale(lerp(
			origin_height_scale_offset, origin_wrist_scale_offset, VRManager.vr_user_preferences.eye_to_arm_ratio
		))
		var stilts: float = (
			(player_height * origin_height_scale_offset)
			- (player_height * origin_wrist_scale_offset)
		)
		height_offset = lerp(0.0, stilts, VRManager.vr_user_preferences.eye_to_arm_ratio)
	else:
		height_offset = 0.0
		VRManager.set_origin_world_scale(1.0)

static func _calculate_humanoid_wristspan(p_skeleton: Skeleton3D, p_humanoid_data: HumanoidData) -> float:
	var current_wristspan: float = 0.0

	var left_shoulder_bone_name_id: int = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
		p_skeleton, humanoid_data_const.shoulder_left)
	var right_shoulder_bone_name_id: int = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
		p_skeleton, humanoid_data_const.shoulder_right)

	var left_upper_bone_name_id: int = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
		p_skeleton, humanoid_data_const.upper_arm_left)
	var right_upper_bone_name_id: int = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
		p_skeleton, humanoid_data_const.upper_arm_right)

	if left_upper_bone_name_id != bone_lib_const.NO_BONE and \
	right_upper_bone_name_id != bone_lib_const.NO_BONE:
		var left_upper_transform: Transform3D = bone_lib_const.get_bone_global_rest_transform(
			left_upper_bone_name_id, p_skeleton
		)
		var right_upper_transform: Transform3D = bone_lib_const.get_bone_global_rest_transform(
			right_upper_bone_name_id, p_skeleton
		)

		if left_shoulder_bone_name_id != bone_lib_const.NO_BONE and \
		right_shoulder_bone_name_id != bone_lib_const.NO_BONE:
			var left_shoulder_transform: Transform3D = bone_lib_const.get_bone_global_rest_transform(
				left_shoulder_bone_name_id, p_skeleton
			)
			var right_shoulder_transform: Transform3D = bone_lib_const.get_bone_global_rest_transform(
				right_shoulder_bone_name_id, p_skeleton
			)

			current_wristspan += left_shoulder_transform.origin.distance_to(
				right_shoulder_transform.origin
			)

			var shld_to_upper = left_shoulder_transform.origin.distance_to(
				left_upper_transform.origin)
			print(shld_to_upper)

			current_wristspan += left_shoulder_transform.origin.distance_to(
				left_upper_transform.origin
			)
			current_wristspan += right_shoulder_transform.origin.distance_to(
				right_upper_transform.origin
			)
		else:
			current_wristspan += left_upper_transform.origin.distance_to(
				right_upper_transform.origin
			)

		var left_lower_bone_name_id: int = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
			p_skeleton, humanoid_data_const.forearm_left)
		var right_lower_bone_name_id: int = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
			p_skeleton, humanoid_data_const.forearm_right)

		if left_lower_bone_name_id != bone_lib_const.NO_BONE \
		and right_lower_bone_name_id != bone_lib_const.NO_BONE:
			var left_lower_transform: Transform3D = bone_lib_const.get_bone_global_rest_transform(
				left_lower_bone_name_id, p_skeleton
			)
			var right_lower_transform: Transform3D = bone_lib_const.get_bone_global_rest_transform(
				right_lower_bone_name_id, p_skeleton
			)

			var upper_to_lower = left_upper_transform.origin.distance_to(
				left_lower_transform.origin
			)
			print(upper_to_lower)

			current_wristspan += left_upper_transform.origin.distance_to(
				left_lower_transform.origin
			)

			current_wristspan += right_upper_transform.origin.distance_to(
				right_lower_transform.origin
			)

			var left_hand_bone_name_id: int = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.hand_left)
			var right_hand_bone_name_id: int = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
				p_skeleton, humanoid_data_const.hand_right)

			if left_hand_bone_name_id != bone_lib_const.NO_BONE \
			and right_hand_bone_name_id != bone_lib_const.NO_BONE:
				var left_wrist_transform: Transform3D = bone_lib_const.get_bone_global_rest_transform(
					left_hand_bone_name_id, p_skeleton
				)
				var right_wrist_transform: Transform3D = bone_lib_const.get_bone_global_rest_transform(
					right_hand_bone_name_id, p_skeleton
				)

				var lower_to_hand = left_lower_transform.origin.distance_to(
					left_wrist_transform.origin
				)
				print(lower_to_hand)

				current_wristspan += left_lower_transform.origin.distance_to(
					left_wrist_transform.origin
				)
				current_wristspan += right_lower_transform.origin.distance_to(
					right_wrist_transform.origin
				)

	return current_wristspan

func _setup_avatar_eyes(
	_p_avatar_node: Node3D,
	p_skeleton: Skeleton3D,
	p_humanoid_data: HumanoidData
	) -> void:
	var eye_spatial: Node3D = avatar_node.get_node_or_null(avatar_node.eye_transform_node_path)
	var eye_global_transform: Transform3D
	if eye_spatial:
		# Get the global transform of the eye relative to the avatar root
		eye_global_transform = node_util_const.get_relative_global_transform(avatar_node, eye_spatial)
	else:
		var found_eyes: bool = false
		if p_skeleton and humanoid_data:
			var eye_left_bone_id: int = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
			p_skeleton, humanoid_data_const.eye_left)
			var eye_right_bone_id: int = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
			p_skeleton, humanoid_data_const.eye_right)

			if eye_left_bone_id != bone_lib_const.NO_BONE \
			and eye_right_bone_id != bone_lib_const.NO_BONE:
				var eye_left_global_transform: Transform3D = bone_lib_const.get_bone_global_rest_transform(eye_left_bone_id, p_skeleton)
				var eye_right_global_transform: Transform3D = bone_lib_const.get_bone_global_rest_transform(eye_right_bone_id, p_skeleton)

				eye_global_transform =\
				node_util_const.get_relative_global_transform(avatar_node, p_skeleton)\
				* eye_left_global_transform.interpolate_with(eye_right_global_transform, 0.5)

				found_eyes = true

		if !found_eyes:
			eye_global_transform = Transform3D(Basis(), Vector3(0.0, 1.0, 0.0) * (default_avatar_height - vr_constants_const.EYE_TO_TOP_OF_HEAD))

	eye_global_transform = Transform3D(Basis(), eye_global_transform.origin)

	avatar_eye_height = eye_global_transform.origin.y
	if _player_input_node:
		_player_input_node.camera_height = eye_global_transform.origin.y - AVATAR_LOWER_DISTANCE

	var eye_offset_transform: Transform3D = Transform3D()

	if p_humanoid_data and p_skeleton:
		avatar_node.set_as_top_level(true)
		avatar_node.set_global_transform(Transform3D(AVATAR_BASIS, Vector3()))
		var head_bone_id: int = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(
			p_skeleton, humanoid_data_const.head)
		if head_bone_id != bone_lib_const.NO_BONE:
			var head_global_rest_transfrom: Transform3D = \
			node_util_const.get_relative_global_transform(avatar_node, p_skeleton)\
			* bone_lib_const.get_bone_global_rest_transform(head_bone_id, p_skeleton)

			eye_offset_transform = head_global_rest_transfrom.affine_inverse() * eye_global_transform

		avatar_wristspan = _calculate_humanoid_wristspan(p_skeleton, p_humanoid_data)
	else:
		avatar_node.set_transform(Transform3D(AVATAR_BASIS, Vector3()))
		avatar_node.set_as_top_level(false)
		avatar_wristspan = (VRManager.vr_user_preferences.custom_player_height
		* VRManager.vr_user_preferences.custom_player_armspan_to_height_ratio
		* vr_constants_const.ARMSPAN_WRIST_SPAN_CONVERSION)

	_ik_space.eye_offset = eye_offset_transform.origin

func _setup_avatar_mouth(
	p_avatar_node: Node,
	p_skeleton: Skeleton3D,
	p_humanoid_data: HumanoidData
	) -> void:
	# Head
	var head_global_transform: Transform3D = Transform3D()
	if head_id != bone_lib_const.NO_BONE and p_skeleton:
		head_global_transform =\
		node_util_const.get_relative_global_transform(p_avatar_node, p_skeleton)\
		* bone_lib_const.get_bone_global_rest_transform(head_id, p_skeleton)
	else:
		head_global_transform = Transform3D(Basis(), Vector3(0.0, 1.0, 0.0) * (default_avatar_height))

	# Mouth
	var mouth_spatial: Node3D = p_avatar_node.get_node_or_null(p_avatar_node.mouth_transform_node_path)
	var mouth_global_transform: Transform3D
	if mouth_spatial:
		# Get the global transform of the mouth relative to the avatar root
		mouth_global_transform =\
		node_util_const.get_relative_global_transform(p_avatar_node, p_skeleton)\
		* mouth_spatial.transform
	else:
		mouth_global_transform = head_global_transform

	relative_mouth_transform = head_global_transform.affine_inverse() * mouth_global_transform
	
	if p_humanoid_data != null and p_skeleton != null:
		setup_bone_attachments(p_humanoid_data, p_skeleton)

	# Change the world scale to match
	if is_multiplayer_authority():
		calculate_proportions()
	else:
		pass

	_update_voice_player()

func _setup_hand_poses(p_avatar_node: Node, p_skeleton: Skeleton3D) -> void:
	if p_skeleton:
		# Generate animation controller, tree, and player
		var animation_player: AnimationPlayer = AnimationPlayer.new()
		animation_player.set_name("AnimationPlayer")
		p_avatar_node.add_child(animation_player)
		animation_player.root_node = animation_player.get_path_to(p_avatar_node)

		animation_player = avatar_setup_const.setup_default_hand_animations(animation_player, p_avatar_node, avatar_skeleton, humanoid_data)

		var animation_tree: AnimationTree = AnimationTree.new()
		animation_tree.set_name("AnimationTree")
		p_avatar_node.add_child(animation_tree)

		animation_tree = avatar_setup_const.setup_animation_tree_hand_blend_tree(
			p_avatar_node,
			animation_tree,
			animation_player,
			p_skeleton,
			humanoid_data
		)

		var avatar_default_driver: Node = avatar_default_driver_const.new()
		avatar_default_driver.set_name("DefaultAvatarDriver")
		p_avatar_node.add_child(avatar_default_driver)
		avatar_default_driver.anim_tree = avatar_default_driver.get_path_to(animation_tree)

		p_avatar_node.driver_node = avatar_default_driver

		# Make the avatar's hand pose match the player internal
		var player_hand_controller: Node = get_node_or_null(player_hand_controller_path)
		if player_hand_controller:
			player_hand_controller.update_driver()

func setup_avatar_instantiate(p_avatar_node: Node3D) -> void:
	avatar_skeleton = null

	if p_avatar_node and (\
		p_avatar_node.get_script() == avatar_definition_const or\
		p_avatar_node.get_script() == avatar_definition_runtime_const):

		avatar_node = p_avatar_node
		add_child(avatar_node)

		# Get the skeleton and humanoid data
		humanoid_data = p_avatar_node.humanoid_data as HumanoidData
		avatar_skeleton = (
			p_avatar_node.get_node_or_null(avatar_node.skeleton_path) as Skeleton3D
		)
		if avatar_skeleton == null:
			avatar_skeleton = null

		# Eye
		_setup_avatar_eyes(avatar_node, avatar_skeleton, humanoid_data)

		# Mouth
		_setup_avatar_mouth(avatar_node, avatar_skeleton, humanoid_data)

		# Hands
		_setup_hand_poses(avatar_node, avatar_skeleton)

		# IK assignments
		var ren_ik: Node = get_node_or_null(_ren_ik_path)
		if ren_ik and _ik_space:
			if avatar_skeleton:
				ren_ik.set("armature_skeleton_path", ren_ik.get_path_to(avatar_skeleton))
				assign_ik_bone_assignments(ren_ik, avatar_skeleton, humanoid_data)

		emit_signal("avatar_setup_complete")
	else:
		emit_signal("avatar_setup_failed")

func try_head_shrink() -> void:
	if shrink_mode == int(shrink_enum.SHRINK) or \
	(shrink_mode == int(shrink_enum.DETERMINED_BY_VIEW) and _player_camera_controller): # FIXME: and _player_camera_controller.camera_mode == player_camera_controller_const.CAMERA_FIRST_PERSON):
		shrink_head()


func shrink_head() -> void:
	if avatar_skeleton and head_id != bone_lib_const.NO_BONE:
		var custom_head_pose: Transform3D = bone_lib_const.fast_get_bone_global_pose(avatar_skeleton, head_id)
		var custom_head_pose_parent: Transform3D = bone_lib_const.fast_get_bone_global_pose(avatar_skeleton, avatar_skeleton.get_bone_parent(head_id))
		custom_head_pose = Transform3D(custom_head_pose.basis.orthonormalized().scaled(Vector3(0.000001, 0.000001, 0.000001)), custom_head_pose_parent.origin)
		avatar_skeleton.set_bone_global_pose_override(head_id, custom_head_pose, 1.0, true)
		# FIXME(lyuma): I don't understand why doing this twice makes it work, but it does...
		custom_head_pose = bone_lib_const.fast_get_bone_global_pose(avatar_skeleton, head_id)
		custom_head_pose = Transform3D(custom_head_pose.basis.orthonormalized().scaled(Vector3(0.000001, 0.000001, 0.000001)), custom_head_pose_parent.origin)
		avatar_skeleton.set_bone_global_pose_override(head_id, custom_head_pose, 1.0, true)

func save_head() -> void:
	if avatar_skeleton and head_id != bone_lib_const.NO_BONE:
		saved_head_transform = bone_lib_const.fast_get_bone_global_pose(avatar_skeleton, head_id)

func restore_head() -> void:
	if avatar_skeleton and head_id != bone_lib_const.NO_BONE:
		var custom_head_pose: Transform3D = bone_lib_const.fast_get_bone_global_pose(avatar_skeleton, head_id)
		custom_head_pose = Transform3D(custom_head_pose.basis.orthonormalized().scaled(saved_head_transform.basis.get_scale()), custom_head_pose.origin)
		avatar_skeleton.set_bone_global_pose_override(head_id, custom_head_pose, 1.0, true)

func get_head_forward_transform() -> Transform3D:
	var head_transform: Transform3D

	if avatar_skeleton and head_id != bone_lib_const.NO_BONE:
		head_transform = avatar_skeleton.global_transform\
		* bone_lib_const.fast_get_bone_global_pose(avatar_skeleton, head_id)
	else:
		head_transform = global_transform * Transform3D(Basis(), Vector3.UP)

	head_transform.basis.z = -head_transform.basis.z
	return head_transform

func _setup_voice() -> void:
	if ! is_multiplayer_authority():
		var godot_speech: Node = get_node_or_null("/root/GodotSpeech")
		if godot_speech:
			if ! voice_player:
				voice_player = get_node_or_null(voice_player_path)

			godot_speech.voice_controller.add_player_audio(get_multiplayer_authority(), voice_player)

###


func _entity_ready() -> void:
	if !Engine.is_editor_hint():
		if is_multiplayer_authority():
			assert(VRManager.connect("xr_mode_changed", self._xr_mode_changed) == OK)
			assert(VRManager.connect("proportions_changed", self._proportions_changed) == OK)

	top_level = false
	set_transform(Transform3D(AVATAR_BASIS, Vector3()))

	_setup_voice()

	_player_camera_controller = get_node_or_null(player_camera_controller_path)
	_ik_space = get_node_or_null(_ik_space_path)
	_player_input_node = get_node_or_null(player_input_path)

	#_instance_avatar()

func _threaded_instance_setup() -> void:
	create_bone_attachments()
	setup_bone_attachments(null, null)


func _on_avatar_ready(p_packed_scene: PackedScene):
	_avatar_ready(p_packed_scene)
