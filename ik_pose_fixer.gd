extends Reference
tool

const DELETE_HELPER_NODES = true

const node_util_const = preload("res://addons/gdutil/node_util.gd")
const avatar_constants_const = preload("avatar_constants.gd")
const bone_lib_const = preload("bone_lib.gd")
const avatar_callback_const = preload("avatar_callback.gd")
const humanoid_data_const = preload("res://addons/vsk_avatar/humanoid_data.gd")

const FORWARD_BASIS: Basis = Basis(
	Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, -1.0, 0.0)
)
const MAGNET_LENGTH = 1000.0

const UP_VECTOR: Vector3 = Vector3(0.0, 1.0, 0.0)
const DOWN_VECTOR: Vector3 = Vector3(0.0, -1.0, 0.0)

const BONE_SNAP_DEGREES = 45
const THUMB_SNAP_DEGREES = 90
const FINGER_SNAP_DEGREES = 45

# Oh god, make it stop...
const IK_CALCULATION_ITERATIONS = 10
const CHAIN_LENGTH_FACTOR = 10

enum chain_ids {
	SPINE_CHAIN,
	NECK_CHAIN,
	LEFT_ARM_CHAIN,
	RIGHT_ARM_CHAIN,
	LEFT_LEG_CHAIN,
	RIGHT_LEG_CHAIN,
}

var hips_name: String = ""
var spine_end_name: String = ""

var neck_name: String = ""
var head_name: String = ""

var left_arm_start_name: String = ""
var right_arm_start_name: String = ""
var left_arm_end_name: String = ""
var right_arm_end_name: String = ""

var left_leg_start_name: String = ""
var right_leg_start_name: String = ""
var left_leg_end_name: String = ""
var right_leg_end_name: String = ""

var upper_left_arm_name: String = ""
var upper_right_arm_name: String = ""

var lower_left_arm_name: String = ""
var lower_right_arm_name: String = ""

var spine_ik: SkeletonIK = null
var neck_ik: SkeletonIK = null
var left_arm_ik: SkeletonIK = null
var right_arm_ik: SkeletonIK = null
var left_leg_ik: SkeletonIK = null
var right_leg_ik: SkeletonIK = null

var hips_point: Spatial = null
var spine_end_point: Spatial = null

var neck_point: Spatial = null
var head_point: Spatial = null

var upper_arm_left_point: Spatial = null
var upper_arm_right_point: Spatial = null

var lower_arm_left_point: Spatial = null
var lower_arm_right_point: Spatial = null

var arm_start_left_point: Spatial = null
var arm_end_left_point: Spatial = null

var arm_start_right_point: Spatial = null
var arm_end_right_point: Spatial = null

var left_hand_rotation: Vector3 = Vector3()
var right_hand_rotation: Vector3 = Vector3()

var leg_start_left_point: Spatial = null
var leg_end_left_point: Spatial = null

var leg_start_right_point: Spatial = null
var leg_end_right_point: Spatial = null

var left_leg_rotation: Vector3 = Vector3()
var right_leg_rotation: Vector3 = Vector3()
	
class Digit:
	extends Reference
	const humanoid_data_const = preload("res://addons/vsk_avatar/humanoid_data.gd")

	var start_name: String = ""
	var mid_name: String = ""
	var end_name: String = ""
	var ik: SkeletonIK = null
	var start_point: Position3D = null
	var mid_point: Position3D = null
	var end_point: Position3D = null
	var rotation = Vector3()

	func _init(
		p_name: String,
		p_side: int,
		p_skeleton: Skeleton,
		p_humanoid_data: humanoid_data_const,
		p_root: Node
	) -> void:
		var side_name: String = avatar_constants_const.get_name_for_side(p_side)

		var humanoid_start_bone_name: String = (
			"%s_%s_%s_bone_name"
			% [p_name, avatar_constants_const.PROXIMAL_NAME, side_name]
		)
		var humanoid_mid_bone_name: String = (
			"%s_%s_%s_bone_name"
			% [p_name, avatar_constants_const.INTERMEDIATE_NAME, side_name]
		)
		var humanoid_end_bone_name: String = (
			"%s_%s_%s_bone_name"
			% [p_name, avatar_constants_const.DISTAL_NAME, side_name]
		)

		start_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
			p_skeleton, p_humanoid_data, humanoid_start_bone_name
		)
		mid_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
			p_skeleton, p_humanoid_data, humanoid_mid_bone_name
		)
		end_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
			p_skeleton, p_humanoid_data, humanoid_end_bone_name
		)
		
		if start_name == "" or mid_name == "" or end_name == "":
			print("Adding {side_name} {digit_name} IK".format({"side_name":side_name, "digit_name":p_name}))
			return

		print("Adding {side_name} {digit_name} IK".format({"side_name":side_name, "digit_name":p_name}))

		ik = SkeletonIK.new()
		ik.set_name("%s_%s_ik" % [p_name, side_name])
		ik.root_bone = start_name
		ik.tip_bone = end_name
		p_skeleton.add_child(ik)
		ik.set_owner(p_root)

		start_point = Position3D.new()
		start_point.set_name("%s_%s_start_point" % [p_name, side_name])
		p_root.add_child(start_point)
		start_point.set_owner(p_root)

		mid_point = Position3D.new()
		mid_point.set_name("%s_%s_mid_point" % [p_name, side_name])
		p_root.add_child(mid_point)
		mid_point.set_owner(p_root)

		end_point = Position3D.new()
		end_point.set_name("%s_%s_end_point" % [p_name, side_name])
		p_root.add_child(end_point)
		end_point.set_owner(p_root)

		print("Getting rotation for {side_name} {digit_name}".format({"side_name":side_name, "digit_name":p_name}))
		rotation = p_skeleton.get_bone_global_pose(p_skeleton.find_bone(end_name)).basis.get_euler()

	func _notification(what):
		match what:
			NOTIFICATION_PREDELETE:
				if ik:
					ik.target_node = NodePath()
					ik.queue_free()
					ik.get_parent().remove_child(ik)
				if start_point:
					start_point.queue_free()
					start_point.get_parent().remove_child(start_point)
				if mid_point:
					mid_point.queue_free()
					mid_point.get_parent().remove_child(mid_point)
				if end_point:
					end_point.queue_free()
					end_point.get_parent().remove_child(end_point)


class Hand:
	extends Reference
	const humanoid_data_const = preload("res://addons/vsk_avatar/humanoid_data.gd")

	var thumb: Digit = null
	var index: Digit = null
	var middle: Digit = null
	var ring: Digit = null
	var little: Digit = null

	func _init(
		p_side: int, p_skeleton: Skeleton, p_humanoid_data: humanoid_data_const, p_root: Node
	) -> void:
		thumb = Digit.new("thumb", p_side, p_skeleton, p_humanoid_data, p_root)
		index = Digit.new("index", p_side, p_skeleton, p_humanoid_data, p_root)
		middle = Digit.new("middle", p_side, p_skeleton, p_humanoid_data, p_root)
		ring = Digit.new("ring", p_side, p_skeleton, p_humanoid_data, p_root)
		little = Digit.new("little", p_side, p_skeleton, p_humanoid_data, p_root)


var left_hand = null
var right_hand = null

static func get_axis_aligned_normal(p_normal: Vector3) -> Vector3:
	var fixed_normal: Vector3 = Vector3()
	fixed_normal.x = round(p_normal.x)
	fixed_normal.y = round(p_normal.y)
	fixed_normal.z = round(p_normal.z)

	return fixed_normal

static func get_axis_aligned_rotation(p_basis: Basis) -> Basis:
	var fixed_basis: Basis = Basis(p_basis.get_rotation_quat())

	fixed_basis.x = get_axis_aligned_normal(fixed_basis.x)
	fixed_basis.y = get_axis_aligned_normal(fixed_basis.y)
	fixed_basis.z = get_axis_aligned_normal(fixed_basis.z)

	return fixed_basis

static func get_snapped_rotation(p_basis: Basis, p_degrees: int) -> Basis:
	var radians: Vector3 = p_basis.get_euler()
	radians.x = deg2rad(round(rad2deg(radians.x) / p_degrees) * p_degrees)
	radians.y = deg2rad(round(rad2deg(radians.y) / p_degrees) * p_degrees)
	radians.z = deg2rad(round(rad2deg(radians.z) / p_degrees) * p_degrees)

	return Basis(radians)

static func missing_root_error(p_chain: int):
	match p_chain:
		chain_ids.SPINE_CHAIN:
			return avatar_callback_const.AVATAR_SPINE_ROOT_MISSING
		chain_ids.NECK_CHAIN:
			return avatar_callback_const.AVATAR_NECK_ROOT_MISSING
		chain_ids.LEFT_ARM_CHAIN:
			return avatar_callback_const.AVATAR_ARM_LEFT_ROOT_MISSING
		chain_ids.RIGHT_ARM_CHAIN:
			return avatar_callback_const.AVATAR_ARM_RIGHT_ROOT_MISSING
		chain_ids.LEFT_LEG_CHAIN:
			return avatar_callback_const.AVATAR_LEG_LEFT_ROOT_MISSING
		chain_ids.RIGHT_LEG_CHAIN:
			return avatar_callback_const.AVATAR_LEG_RIGHT_ROOT_MISSING
		_:
			return avatar_callback_const.AVATAR_FAILED
			
static func missing_tip_error(p_chain: int):
	match p_chain:
		chain_ids.SPINE_CHAIN:
			return avatar_callback_const.AVATAR_SPINE_TIP_MISSING
		chain_ids.NECK_CHAIN:
			return avatar_callback_const.AVATAR_NECK_TIP_MISSING
		chain_ids.LEFT_ARM_CHAIN:
			return avatar_callback_const.AVATAR_ARM_LEFT_TIP_MISSING
		chain_ids.RIGHT_ARM_CHAIN:
			return avatar_callback_const.AVATAR_ARM_RIGHT_TIP_MISSING
		chain_ids.LEFT_LEG_CHAIN:
			return avatar_callback_const.AVATAR_LEG_LEFT_TIP_MISSING
		chain_ids.RIGHT_LEG_CHAIN:
			return avatar_callback_const.AVATAR_LEG_RIGHT_TIP_MISSING
		_:
			return avatar_callback_const.AVATAR_FAILED
			
static func chain_mismatch_error(p_chain: int) -> int:
	match p_chain:
		chain_ids.SPINE_CHAIN:
			return avatar_callback_const.AVATAR_SPINE_BONES_MISORDERED
		chain_ids.NECK_CHAIN:
			return avatar_callback_const.AVATAR_NECK_BONES_MISORDERED
		chain_ids.LEFT_ARM_CHAIN:
			return avatar_callback_const.AVATAR_ARM_LEFT_BONES_MISORDERED
		chain_ids.RIGHT_ARM_CHAIN:
			return avatar_callback_const.AVATAR_ARM_RIGHT_BONES_MISORDERED
		chain_ids.LEFT_LEG_CHAIN:
			return avatar_callback_const.AVATAR_LEG_LEFT_BONES_MISORDERED
		chain_ids.RIGHT_LEG_CHAIN:
			return avatar_callback_const.AVATAR_LEG_RIGHT_BONES_MISORDERED
		_:
			return avatar_callback_const.AVATAR_FAILED

static func validate_chain(p_skeleton: Skeleton, p_chain: int, p_root: String, p_tip: String) -> int:
	if p_skeleton == null:
		return avatar_callback_const.SKELETON_IS_NULL
	
	var root_id: int = p_skeleton.find_bone(p_root)
	var tip_id: int = p_skeleton.find_bone(p_tip)
	
	if root_id == -1:
		printerr("Missing root %s!" % p_tip)
		return missing_root_error(p_chain)
	if tip_id == -1:
		printerr("Missing tip %s!" % p_tip)
		return missing_tip_error(p_chain)
	if root_id >= tip_id:
		return chain_mismatch_error(p_chain)
	
	return avatar_callback_const.AVATAR_OK
	
static func setup_ik(p_skeleton: Skeleton, p_ik_point_root: Node, p_ik_name: String, p_chain_id: int, p_root_name: String, p_tip_name: String) -> SkeletonIK:
	var ik_node: SkeletonIK = SkeletonIK.new()
	ik_node.set_name(p_ik_name)
	ik_node.root_bone = p_root_name
	ik_node.tip_bone = p_tip_name
	p_skeleton.add_child(ik_node)
	ik_node.set_owner(p_ik_point_root)
	
	return ik_node
	
static func get_x_direction(p_root: Spatial, p_skeleton: Skeleton, p_start: int, p_end: int) -> Vector3:
	var start_transform: Transform = node_util_const.get_relative_global_transform(p_root, p_skeleton)\
	* bone_lib_const.get_bone_global_rest_transform(p_start, p_skeleton)
	var end_transform: Transform = node_util_const.get_relative_global_transform(p_root, p_skeleton)\
	* bone_lib_const.get_bone_global_rest_transform(p_end, p_skeleton)
	
	if start_transform.origin.x > end_transform.origin.x:
		return Vector3(-1.0, 0.0, 0.0)
	else:
		return Vector3(1.0, 0.0, 0.0)

func create_points(
	p_ik_point_root: Spatial, p_skeleton: Skeleton, p_humanoid_data: humanoid_data_const
) -> int:
	print("create_points")
	left_arm_start_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "shoulder_left_bone_name"
	)
	right_arm_start_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "shoulder_right_bone_name"
	)
	left_arm_end_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "hand_left_bone_name"
	)
	right_arm_end_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "hand_right_bone_name"
	)

	upper_left_arm_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "upper_arm_left_bone_name"
	)
	upper_right_arm_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "upper_arm_right_bone_name"
	)

	lower_left_arm_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "forearm_left_bone_name"
	)
	lower_right_arm_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "forearm_right_bone_name"
	)

	if left_arm_start_name == "" or right_arm_start_name == "":
		left_arm_start_name = upper_left_arm_name
		right_arm_start_name = upper_right_arm_name

	left_leg_start_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "thigh_left_bone_name"
	)
	right_leg_start_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "thigh_right_bone_name"
	)
	left_leg_end_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "foot_left_bone_name"
	)
	right_leg_end_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "foot_right_bone_name"
	)

	hips_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "hips_bone_name"
	)
	spine_end_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "upper_chest_bone_name"
	)
	neck_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "neck_bone_name"
	)
	head_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
		p_skeleton, p_humanoid_data, "head_bone_name"
	)

	destroy_points()

	if spine_end_name == "":
		spine_end_name = bone_lib_const.get_internal_bone_name_for_humanoid_bone(
			p_skeleton, p_humanoid_data, "chest_bone_name"
		)

	if (
		hips_name == ""
		or spine_end_name == ""
		or neck_name == ""
		or head_name == ""
		or left_arm_start_name == ""
		or right_arm_start_name == ""
		or left_arm_end_name == ""
		or right_arm_end_name == ""
		or upper_left_arm_name == ""
		or upper_right_arm_name == ""
		or lower_left_arm_name == ""
		or lower_right_arm_name == ""
	):
		return avatar_callback_const.AVATAR_COULD_NOT_CREATE_POINTS

	hips_point = Position3D.new()
	hips_point.set_name("HipsPoint")
	p_ik_point_root.add_child(hips_point)
	hips_point.set_owner(p_ik_point_root)

	spine_end_point = Position3D.new()
	spine_end_point.set_name("SpineEndPoint")
	p_ik_point_root.add_child(spine_end_point)
	spine_end_point.set_owner(p_ik_point_root)

	neck_point = Position3D.new()
	neck_point.set_name("NeckPoint")
	p_ik_point_root.add_child(neck_point)
	neck_point.set_owner(p_ik_point_root)

	head_point = Position3D.new()
	head_point.set_name("HeadPoint")
	p_ik_point_root.add_child(head_point)
	head_point.set_owner(p_ik_point_root)

	########
	# Arms #
	########
	upper_arm_left_point = Position3D.new()
	upper_arm_left_point.set_name("UpperArmLeftPoint")
	p_ik_point_root.add_child(upper_arm_left_point)
	upper_arm_left_point.set_owner(p_ik_point_root)

	upper_arm_right_point = Position3D.new()
	upper_arm_right_point.set_name("UpperArmRightPoint")
	p_ik_point_root.add_child(upper_arm_right_point)
	upper_arm_right_point.set_owner(p_ik_point_root)

	lower_arm_left_point = Position3D.new()
	lower_arm_left_point.set_name("LowerArmLeftPoint")
	p_ik_point_root.add_child(lower_arm_left_point)
	lower_arm_left_point.set_owner(p_ik_point_root)

	lower_arm_right_point = Position3D.new()
	lower_arm_right_point.set_name("LowerArmRightPoint")
	p_ik_point_root.add_child(lower_arm_right_point)
	lower_arm_right_point.set_owner(p_ik_point_root)

	arm_start_left_point = Position3D.new()
	arm_start_left_point.set_name("ArmStartLeftPoint")
	p_ik_point_root.add_child(arm_start_left_point)
	arm_start_left_point.set_owner(p_ik_point_root)

	arm_end_left_point = Position3D.new()
	arm_end_left_point.set_name("ArmEndLeftPoint")
	p_ik_point_root.add_child(arm_end_left_point)
	arm_end_left_point.set_owner(p_ik_point_root)

	arm_start_right_point = Position3D.new()
	arm_start_right_point.set_name("ArmStartRightPoint")
	p_ik_point_root.add_child(arm_start_right_point)
	arm_start_right_point.set_owner(p_ik_point_root)

	arm_end_right_point = Position3D.new()
	arm_end_right_point.set_name("ArmEndRightPoint")
	p_ik_point_root.add_child(arm_end_right_point)
	arm_end_right_point.set_owner(p_ik_point_root)

	########
	# Legs #
	########
	leg_start_left_point = Position3D.new()
	leg_start_left_point.set_name("LegStartLeftPoint")
	p_ik_point_root.add_child(leg_start_left_point)
	leg_start_left_point.set_owner(p_ik_point_root)

	leg_end_left_point = Position3D.new()
	leg_end_left_point.set_name("LegEndLeftPoint")
	p_ik_point_root.add_child(leg_end_left_point)
	leg_end_left_point.set_owner(p_ik_point_root)

	leg_start_right_point = Position3D.new()
	leg_start_right_point.set_name("LegStartRightPoint")
	p_ik_point_root.add_child(leg_start_right_point)
	leg_start_right_point.set_owner(p_ik_point_root)

	leg_end_right_point = Position3D.new()
	leg_end_right_point.set_name("LegEndRightPoint")
	p_ik_point_root.add_child(leg_end_right_point)
	leg_end_right_point.set_owner(p_ik_point_root)

	print("Adding Spine IK")
	var spine_chain_validation: int = validate_chain(p_skeleton, chain_ids.SPINE_CHAIN, hips_name, spine_end_name)
	if spine_chain_validation == avatar_callback_const.AVATAR_OK:
		spine_ik = setup_ik(p_skeleton, p_ik_point_root, "SpineIK", chain_ids.SPINE_CHAIN, hips_name, spine_end_name)
	else:
		return spine_chain_validation

	print("Adding Neck IK")
	var neck_chain_validation: int = validate_chain(p_skeleton, chain_ids.NECK_CHAIN, neck_name, head_name)
	if neck_chain_validation == avatar_callback_const.AVATAR_OK:
		neck_ik = setup_ik(p_skeleton, p_ik_point_root, "NeckIK", chain_ids.NECK_CHAIN, neck_name, head_name)
	else:
		return neck_chain_validation
		
	########
	# Arms #
	########
	print("Adding Left Arm IK")
	var left_arm_chain_validation: int = validate_chain(p_skeleton, chain_ids.LEFT_ARM_CHAIN, left_arm_start_name, left_arm_end_name)
	if left_arm_chain_validation == avatar_callback_const.AVATAR_OK:
		left_arm_ik = setup_ik(p_skeleton, p_ik_point_root, "LeftArmIK", chain_ids.LEFT_ARM_CHAIN, left_arm_start_name, left_arm_end_name)
	else:
		return left_arm_chain_validation
	
	print("Adding Right Arm IK")
	var right_arm_chain_validation: int = validate_chain(p_skeleton, chain_ids.RIGHT_ARM_CHAIN, right_arm_start_name, right_arm_end_name)
	if right_arm_chain_validation == avatar_callback_const.AVATAR_OK:
		right_arm_ik = setup_ik(p_skeleton, p_ik_point_root, "RightArmIK", chain_ids.RIGHT_ARM_CHAIN, right_arm_start_name, right_arm_end_name)
	else:
		return right_arm_chain_validation


	print("Getting hand global rotation...")
	left_hand_rotation = p_skeleton.get_bone_global_pose(p_skeleton.find_bone(left_arm_end_name)).basis.get_euler()
	right_hand_rotation = p_skeleton.get_bone_global_pose(p_skeleton.find_bone(right_arm_end_name)).basis.get_euler()

	###########
	# Digits #
	###########

	left_hand = Hand.new(
		avatar_constants_const.SIDE_LEFT, p_skeleton, p_humanoid_data, p_ik_point_root
	)
	right_hand = Hand.new(
		avatar_constants_const.SIDE_RIGHT, p_skeleton, p_humanoid_data, p_ik_point_root
	)

	########
	# Legs #
	########
	print("Adding Left Leg IK")
	var left_leg_chain_validation: int = validate_chain(p_skeleton, chain_ids.LEFT_LEG_CHAIN, left_leg_start_name, left_leg_end_name)
	if left_leg_chain_validation == avatar_callback_const.AVATAR_OK:
		left_leg_ik = setup_ik(p_skeleton, p_ik_point_root, "LeftLegIK", chain_ids.LEFT_LEG_CHAIN, left_leg_start_name, left_leg_end_name)
	else:
		return left_leg_chain_validation
	
	print("Adding Right Leg IK")
	var right_leg_chain_validation: int = validate_chain(p_skeleton, chain_ids.RIGHT_LEG_CHAIN, right_leg_start_name, right_leg_end_name)
	if right_leg_chain_validation == avatar_callback_const.AVATAR_OK:
		right_leg_ik = setup_ik(p_skeleton, p_ik_point_root, "RightLegIK", chain_ids.RIGHT_LEG_CHAIN, right_leg_start_name, right_leg_end_name)
	else:
		return right_leg_chain_validation

	print("Getting leg global rotation...")
	left_leg_rotation = p_skeleton.get_bone_global_pose(p_skeleton.find_bone(left_leg_end_name)).basis.get_euler()
	right_leg_rotation = p_skeleton.get_bone_global_pose(p_skeleton.find_bone(right_leg_end_name)).basis.get_euler()

	return avatar_callback_const.AVATAR_OK


func destroy_points() -> void:
	print("destroy_points")

	######
	# IK #
	######

	left_hand = null
	right_hand = null

	#########
	# Spine #
	#########
	if spine_ik:
		spine_ik.target_node = NodePath()
		spine_ik.queue_free()
		spine_ik.get_parent().remove_child(spine_ik)
		spine_ik = null

	if neck_ik:
		neck_ik.target_node = NodePath()
		neck_ik.queue_free()
		neck_ik.get_parent().remove_child(neck_ik)
		neck_ik = null

	########
	# Arms #
	########
	if left_arm_ik:
		left_arm_ik.target_node = NodePath()
		left_arm_ik.queue_free()
		left_arm_ik.get_parent().remove_child(left_arm_ik)
		left_arm_ik = null

	if right_arm_ik:
		right_arm_ik.target_node = NodePath()
		right_arm_ik.queue_free()
		right_arm_ik.get_parent().remove_child(right_arm_ik)
		right_arm_ik = null

	##########
	# Digits #
	##########
	left_hand = null
	right_hand = null

	########
	# Legs #
	########
	if left_leg_ik:
		left_leg_ik.target_node = NodePath()
		left_leg_ik.queue_free()
		left_leg_ik.get_parent().remove_child(left_leg_ik)
		left_leg_ik = null

	if right_leg_ik:
		right_leg_ik.target_node = NodePath()
		right_leg_ik.queue_free()
		right_leg_ik.get_parent().remove_child(right_leg_ik)
		right_leg_ik = null

	##########
	# Points #
	##########

	#########
	# Spine #
	#########
	if hips_point:
		hips_point.queue_free()
		hips_point.get_parent().remove_child(hips_point)
		hips_point = null

	if spine_end_point:
		spine_end_point.queue_free()
		spine_end_point.get_parent().remove_child(spine_end_point)
		spine_end_point = null

	if neck_point:
		neck_point.queue_free()
		neck_point.get_parent().remove_child(neck_point)
		neck_point = null

	if head_point:
		head_point.queue_free()
		head_point.get_parent().remove_child(head_point)
		head_point = null

	########
	# Arms #
	########
	if upper_arm_left_point:
		upper_arm_left_point.queue_free()
		upper_arm_left_point.get_parent().remove_child(upper_arm_left_point)
		upper_arm_left_point = null

	if upper_arm_right_point:
		upper_arm_right_point.queue_free()
		upper_arm_right_point.get_parent().remove_child(upper_arm_right_point)
		upper_arm_right_point = null

	if lower_arm_left_point:
		lower_arm_left_point.queue_free()
		lower_arm_left_point.get_parent().remove_child(lower_arm_left_point)
		lower_arm_left_point = null

	if lower_arm_right_point:
		lower_arm_right_point.queue_free()
		lower_arm_right_point.get_parent().remove_child(lower_arm_right_point)
		lower_arm_right_point = null

	if arm_start_left_point:
		arm_start_left_point.queue_free()
		arm_start_left_point.get_parent().remove_child(arm_start_left_point)
		arm_start_left_point = null

	if arm_end_left_point:
		arm_end_left_point.queue_free()
		arm_end_left_point.get_parent().remove_child(arm_end_left_point)
		arm_end_left_point = null

	if arm_start_right_point:
		arm_start_right_point.queue_free()
		arm_start_right_point.get_parent().remove_child(arm_start_right_point)
		arm_start_right_point = null

	if arm_end_right_point:
		arm_end_right_point.queue_free()
		arm_end_right_point.get_parent().remove_child(arm_end_right_point)
		arm_end_right_point = null

	########
	# Legs #
	########
	if leg_start_left_point:
		leg_start_left_point.queue_free()
		leg_start_left_point.get_parent().remove_child(leg_start_left_point)
		leg_start_left_point = null

	if leg_end_left_point:
		leg_end_left_point.queue_free()
		leg_end_left_point.get_parent().remove_child(leg_end_left_point)
		leg_end_left_point = null

	if leg_start_right_point:
		leg_start_right_point.queue_free()
		leg_start_right_point.get_parent().remove_child(leg_start_right_point)
		leg_start_right_point = null

	if leg_end_right_point:
		leg_end_right_point.queue_free()
		leg_end_right_point.get_parent().remove_child(leg_end_right_point)
		leg_end_right_point = null


static func calculate_closest_axis(p_root_transform, p_tip_transform) -> int:
	var normal_direction = p_root_transform.origin.direction_to(p_tip_transform.origin)

	var root_basis: Basis = p_root_transform.basis
	var x_distance: float = root_basis.x.distance_to(normal_direction)
	var y_distance: float = root_basis.y.distance_to(normal_direction)
	var z_distance: float = root_basis.z.distance_to(normal_direction)

	var closest_axis: int = Vector3.AXIS_Z

	if x_distance < y_distance:
		if x_distance < z_distance:
			closest_axis = Vector3.AXIS_X
	else:
		if y_distance < z_distance:
			closest_axis = Vector3.AXIS_Y
			
	return closest_axis

# Return the estimated bone roll offset for an individual bone in degrees
func calculate_bone_roll_offset(
	p_skeleton: Skeleton, p_bone_id: int, p_child_bone_id: int, p_snap: int
) -> float:
	print("calculate_bone_roll_offset")
	var children: PoolIntArray = PoolIntArray()

	for i in p_skeleton.get_bone_count():
		if p_skeleton.get_bone_parent(i) == p_bone_id:
			children.push_back(i)

	if children.size() != 1:
		return 0.0

	if p_child_bone_id != -1:
		if children[0] != p_child_bone_id:
			return 0.0

	var child_bone_id: int = children[0]

	var root_global_transform: Transform = p_skeleton.get_bone_global_pose(p_bone_id)
	var tip_global_transform: Transform = p_skeleton.get_bone_global_pose(child_bone_id)

	var closest_axis: int = calculate_closest_axis(root_global_transform, tip_global_transform)

	#var dict : Dictionary = root_basis.get_rotation_axis_angle()

	print("closest_axis: %s" % str(closest_axis))

	return 0.0


func setup_bone_chain(p_skeleton: Skeleton, p_bone_chain: PoolIntArray, p_skeleton_ik: SkeletonIK, p_custom_bone_poses: Array) -> Array:
	print("setup_bone_chain")
	p_skeleton_ik.interpolation = 1.0
	for i in range(0, IK_CALCULATION_ITERATIONS):
		p_skeleton_ik.start(true)

	var array_fixed: Array = []
	
	# Saracen: currently this is incorrect because it does not factor the custom_bone_poses into the equation.
	# Leaving it for now since I plan to rewrite this code
	for bone_id in p_skeleton.get_bone_count():
		var ik_transform: Transform = bone_lib_const.local_bone_rotation_from_global_pose(
			p_skeleton, bone_id)
		var rest_transform: Transform = p_skeleton.get_bone_rest(bone_id)

		var offset_transform: Transform = rest_transform.affine_inverse() * ik_transform
		array_fixed.push_back(offset_transform)

	p_skeleton_ik.stop()

	for bone_id in p_skeleton.get_bone_count():
		p_custom_bone_poses[bone_id] = array_fixed[bone_id]
		
	return p_custom_bone_poses


func straighten_vertical(
	p_root: Spatial,
	p_skeleton: Skeleton,
	p_humanoid_data,
	p_start_node: Spatial,
	p_end_node: Spatial,
	p_start_name: String,
	p_end_name: String,
	p_skeleton_ik: SkeletonIK,
	p_roll_fix_pass: bool,
	p_custom_bone_pose_array: Array
) -> Dictionary:
	print("straighten_vertical")
	var start_id: int = -1
	var end_id: int = -1

	var start_node: Spatial = null
	var end_node: Spatial = null

	start_node = p_start_node
	end_node = p_end_node

	start_id = p_skeleton.find_bone(p_start_name)
	end_id = p_skeleton.find_bone(p_end_name)

	if start_node and end_node and p_skeleton_ik and start_id != -1 and end_id != -1:
		var bone_chain: PoolIntArray = bone_lib_const.get_full_bone_chain(
			p_skeleton, start_id, end_id
		)
		var chain_length: float = bone_lib_const.get_bone_chain_length(p_root,
			p_skeleton, bone_chain, false
		)

		var skeleton_global_transform: Transform = Transform(
			Basis(\
			node_util_const.get_relative_global_transform(p_root, p_skeleton).basis.get_rotation_quat()),
			node_util_const.get_relative_global_transform(p_root, p_skeleton).origin
		)

		p_skeleton_ik.use_magnet = true
		p_skeleton_ik.magnet = (
			skeleton_global_transform
			* Vector3(0.0, chain_length * MAGNET_LENGTH, 0.0)
		)

		var start_transform: Transform = (
			skeleton_global_transform
			* p_skeleton.get_bone_global_pose(start_id)
		)
		var end_transform: Transform = (
			skeleton_global_transform
			* p_skeleton.get_bone_global_pose(end_id)
		)

		start_transform.basis = get_snapped_rotation(start_transform.basis, BONE_SNAP_DEGREES)
		end_transform.basis = get_snapped_rotation(end_transform.basis, BONE_SNAP_DEGREES)

		node_util_const.set_relative_global_transform(p_root, start_node, start_transform)
		node_util_const.set_relative_global_transform(p_root, end_node, 
			Transform(
				end_transform.basis, node_util_const.get_relative_global_transform(p_root, start_node).origin + UP_VECTOR * chain_length * CHAIN_LENGTH_FACTOR
			)
		)

		p_skeleton_ik.target_node = p_skeleton_ik.get_path_to(end_node)

		p_custom_bone_pose_array = setup_bone_chain(p_skeleton, bone_chain, p_skeleton_ik, p_custom_bone_pose_array)

		return {"custom_bone_pose_array":p_custom_bone_pose_array, "success":true}

	return {"custom_bone_pose_array":p_custom_bone_pose_array, "success":false}


func straighten_leg(p_root : Spatial,
	p_side: int,
	p_skeleton: Skeleton,
	p_humanoid_data: humanoid_data_const,
	p_roll_fix_pass: bool,
	p_custom_bone_pose_array: Array
) -> Dictionary:
	print("straighten_leg")
	var start_id: int = -1
	var end_id: int = -1

	var start_node: Spatial = null
	var end_node: Spatial = null

	var start_name: String = ""
	var end_name: String = ""

	var rotation: Vector3 = Vector3()

	var ik: SkeletonIK = null

	if p_side == avatar_constants_const.SIDE_RIGHT:
		start_name = right_leg_start_name
		end_name = right_leg_end_name

		start_node = leg_start_right_point
		end_node = leg_end_right_point

		ik = right_leg_ik
		rotation = right_leg_rotation
	else:
		start_name = left_leg_start_name
		end_name = left_leg_end_name

		start_node = leg_start_left_point
		end_node = leg_end_left_point

		ik = left_leg_ik
		rotation = left_leg_rotation

	start_id = p_skeleton.find_bone(start_name)
	end_id = p_skeleton.find_bone(end_name)

	if start_node and end_node and ik and start_id != -1 and end_id != -1:
		var bone_chain: PoolIntArray = bone_lib_const.get_full_bone_chain(
			p_skeleton, start_id, end_id
		)

		var chain_length: float = bone_lib_const.get_bone_chain_length(p_root,
			p_skeleton, bone_chain, false
		)

		var skeleton_global_transform: Transform = Transform(
			Basis(\
			node_util_const.get_relative_global_transform(p_root, p_skeleton).basis.get_rotation_quat()),
			node_util_const.get_relative_global_transform(p_root, p_skeleton).origin
		)

		ik.use_magnet = true
		ik.magnet = skeleton_global_transform * Vector3(0.0, -(chain_length * MAGNET_LENGTH), 0.0)

		
		node_util_const.set_relative_global_transform(p_root, start_node,
			skeleton_global_transform * p_skeleton.get_bone_global_pose(start_id)
		)
		node_util_const.set_relative_global_transform(p_root, end_node,
			(
				Transform(Basis(), DOWN_VECTOR * chain_length)
				* skeleton_global_transform
				* Transform(Basis(rotation), p_skeleton.get_bone_global_pose(start_id).origin)
			)
		)

		ik.target_node = ik.get_path_to(end_node)

		p_custom_bone_pose_array = setup_bone_chain(p_skeleton, bone_chain, ik, p_custom_bone_pose_array)

		return {"custom_bone_pose_array":p_custom_bone_pose_array, "success":true}

	return {"custom_bone_pose_array":p_custom_bone_pose_array, "success":false}


func straighten_arm(p_root : Spatial,
	p_side: int,
	p_skeleton: Skeleton,
	p_humanoid_data: humanoid_data_const,
	p_roll_fix_pass: bool,
	p_custom_bone_pose_array: Array
) -> Dictionary:
	print("straighten_arm")
	var start_id: int = -1
	var end_id: int = -1
	var lower_arm_id: int = -1

	var lower_arm_node: Spatial = null
	var start_node: Spatial = null
	var end_node: Spatial = null

	var direction: Vector3 = Vector3()
	var lower_arm_name: String = ""
	var start_name: String = ""
	var end_name: String = ""

	var rotation: Vector3 = Vector3()

	var ik: SkeletonIK = null

	if p_side == avatar_constants_const.SIDE_RIGHT:
		lower_arm_name = lower_right_arm_name

		start_name = right_arm_start_name
		end_name = right_arm_end_name

		start_node = arm_start_right_point
		end_node = arm_end_right_point
		lower_arm_node = lower_arm_right_point

		ik = right_arm_ik
		rotation = right_hand_rotation
	else:
		lower_arm_name = lower_left_arm_name

		start_name = left_arm_start_name
		end_name = left_arm_end_name

		start_node = arm_start_left_point
		end_node = arm_end_left_point
		lower_arm_node = lower_arm_left_point

		ik = left_arm_ik
		rotation = left_hand_rotation
		
	start_id = p_skeleton.find_bone(start_name)
	end_id = p_skeleton.find_bone(end_name)
	lower_arm_id = p_skeleton.find_bone(lower_arm_name)

	if (
		start_node
		and end_node
		and lower_arm_node
		and start_id != -1
		and end_id != -1
		and lower_arm_id != -1
		and ik
	):
		direction = get_x_direction(p_root, p_skeleton, start_id, end_id)
		
		var bone_chain: PoolIntArray = bone_lib_const.get_full_bone_chain(
			p_skeleton, start_id, end_id
		)

		var chain_length: float = bone_lib_const.get_bone_chain_length(
			p_root, p_skeleton, bone_chain, false
		)

		var skeleton_global_transform: Transform = Transform(
			Basis(\
			node_util_const.get_relative_global_transform(p_root, p_skeleton).basis.get_rotation_quat()),
			node_util_const.get_relative_global_transform(p_root, p_skeleton).origin
		)

		ik.override_tip_basis = true
		ik.use_magnet = true
		ik.magnet = skeleton_global_transform * (direction * chain_length * MAGNET_LENGTH)

		var start_transform: Transform = (
			skeleton_global_transform
			* p_skeleton.get_bone_global_pose(start_id)
		)
		var end_transform: Transform = (
			skeleton_global_transform
			* p_skeleton.get_bone_global_pose(end_id)
		)
		var lower_arm_transform: Transform = (
			skeleton_global_transform
			* p_skeleton.get_bone_global_pose(lower_arm_id)
		)

		node_util_const.set_relative_global_transform(p_root, start_node, start_transform)
		node_util_const.set_relative_global_transform(p_root, lower_arm_node, lower_arm_transform)

		var target_end_position: Vector3 = (
			node_util_const.get_relative_global_transform(p_root, start_node).origin
			+ direction * chain_length
		)

		# Awful workarounds, please clean up...
		var lower_arm_end_position: Vector3 = (
			node_util_const.get_relative_global_transform(p_root, lower_arm_node).origin
			+ direction * chain_length
		)

		var looking_at_start = Transform(Basis(), node_util_const.get_relative_global_transform(p_root, lower_arm_node).origin).looking_at(
			end_transform.origin, Vector3(0.0, 1.0, 0.0)
		)
		var looking_at_end = Transform(Basis(), node_util_const.get_relative_global_transform(p_root, lower_arm_node).origin).looking_at(
			lower_arm_end_position, Vector3(0.0, 1.0, 0.0)
		)

		var end_node_parent: Node = end_node.get_parent()

		node_util_const.set_relative_global_transform(p_root, end_node, Transform(end_transform.basis, target_end_position))
		end_node_parent.remove_child(end_node)

		node_util_const.set_relative_global_transform(p_root, lower_arm_node, looking_at_start)
		lower_arm_node.add_child(end_node)
		node_util_const.set_relative_global_transform(p_root, end_node, Transform(end_transform.basis, target_end_position))
		node_util_const.set_relative_global_transform(p_root, lower_arm_node, looking_at_end)

		var end_node_final_basis: Basis = node_util_const.get_relative_global_transform(p_root, end_node).basis
		end_node.get_parent().remove_child(end_node)

		node_util_const.set_relative_global_transform(p_root, lower_arm_node, lower_arm_transform)
		end_node_parent.add_child(end_node)
		end_node.set_owner(end_node_parent)
		# End

		node_util_const.set_relative_global_transform(p_root, end_node,
			Transform(
				get_snapped_rotation(end_node_final_basis, BONE_SNAP_DEGREES), target_end_position
			)
		)
		ik.target_node = ik.get_path_to(end_node)
		setup_bone_chain(p_skeleton, bone_chain, ik, p_custom_bone_pose_array)

		# Second pass, hand roll fix

		var roll_correction_angle: float = correct_hand_roll(
			p_side, p_skeleton, p_humanoid_data, p_roll_fix_pass
		)
		
		print("%s roll correction angle %s" % [end_name, str(roll_correction_angle)])

		var gt: Transform = Transform()
		
		gt = node_util_const.get_relative_global_transform(p_root, end_node)
		gt.basis = gt.basis.rotated(
			Vector3(1.0, 0.0, 0.0), roll_correction_angle
		)
		node_util_const.set_relative_global_transform(p_root, end_node, gt)
		
		ik.target_node = ik.get_path_to(end_node)  # Must be reset
		p_custom_bone_pose_array = setup_bone_chain(p_skeleton, bone_chain, ik, p_custom_bone_pose_array)

		# Third pass, hand pitch fix

		var pitch_correction_angle: float = correct_hand_pitch(
			p_side, p_skeleton, p_humanoid_data, p_roll_fix_pass
		)
		
		print("%s pitch correction angle %s" % [end_name, str(pitch_correction_angle)])
		
		gt = node_util_const.get_relative_global_transform(p_root, end_node)
		gt.basis = gt.basis.rotated(
			Vector3(0.0, 0.0, 1.0), pitch_correction_angle
		)
		node_util_const.set_relative_global_transform(p_root, end_node, gt)
		
		ik.target_node = ik.get_path_to(end_node)  # Must be reset
		p_custom_bone_pose_array = setup_bone_chain(p_skeleton, bone_chain, ik, p_custom_bone_pose_array)

		return {"custom_bone_pose_array":p_custom_bone_pose_array, "success":true}

	return {"custom_bone_pose_array":p_custom_bone_pose_array, "success":false}


func straighten_digit(
	p_root : Spatial,
	p_side: int,
	p_digit_id: int,
	p_skeleton: Skeleton,
	p_humanoid_data: humanoid_data_const,
	p_hand_basis: Basis,
	p_snap_degrees: float,
	p_roll_fix_pass: bool,
	p_custom_bone_pose_array: Array
) -> Dictionary:
	print("straighten_digit")
	var start_id: int = -1
	var mid_id: int = -1
	var end_id: int = -1
	
	var start_node: Spatial = null
	var end_node: Spatial = null
	
	var direction: Vector3 = Vector3()
	var start_name: String = ""
	var mid_name: String = ""
	var end_name: String = ""
	
	var rotation: Vector3 = Vector3()
	
	var ik: SkeletonIK = null
	
	var hand: Hand = null
	
	if p_side == avatar_constants_const.SIDE_RIGHT:
		hand = right_hand
	else:
		hand = left_hand
		
	if hand:
		var digit: Digit = null
		
		match p_digit_id:
			avatar_constants_const.DIGIT_THUMB:
				digit = hand.thumb
			avatar_constants_const.DIGIT_INDEX:
				digit = hand.index
			avatar_constants_const.DIGIT_MIDDLE:
				digit = hand.middle
			avatar_constants_const.DIGIT_RING:
				digit = hand.ring
			avatar_constants_const.DIGIT_LITTLE:
				digit = hand.little
				
		if digit:
			start_name = digit.start_name
			mid_name = digit.mid_name
			end_name = digit.end_name
			
			start_node = digit.start_point
			end_node = digit.end_point
			
			ik = digit.ik
			
			rotation = digit.rotation
			
			start_id = p_skeleton.find_bone(start_name)
			mid_id = p_skeleton.find_bone(mid_name)
			end_id = p_skeleton.find_bone(end_name)
			
			if start_node and end_node and ik and start_id != -1 and end_id != -1:
				direction = get_x_direction(p_root, p_skeleton, start_id, end_id)
				
				var bone_chain: PoolIntArray = bone_lib_const.get_full_bone_chain(
					p_skeleton, start_id, end_id
				)
				
				var chain_length: float = bone_lib_const.get_bone_chain_length(
					p_root, p_skeleton, bone_chain, false
				)
				
				var skeleton_global_transform: Transform = Transform(
					Basis(\
					node_util_const.get_relative_global_transform(p_root, p_skeleton).basis.get_rotation_quat()),
					node_util_const.get_relative_global_transform(p_root, p_skeleton).origin
				)
				
				ik.override_tip_basis = false
				ik.use_magnet = true
				ik.magnet = Vector3()
				#ik.magnet = skeleton_global_transform * Vector3(0.0, -(chain_length * MAGNET_LENGTH), 0.0)
				
				node_util_const.set_relative_global_transform(p_root, start_node,
					(
						skeleton_global_transform
						* Transform(p_hand_basis, p_skeleton.get_bone_global_pose(start_id).origin)
					)
				)
				
				var target_end_position: Vector3 = (
					node_util_const.get_relative_global_transform(p_root, start_node).origin
					+ direction * (chain_length * CHAIN_LENGTH_FACTOR)
				)
				var end_node_final_basis: Basis = (
					skeleton_global_transform
					* p_skeleton.get_bone_global_pose(end_id)
				).basis

				node_util_const.set_relative_global_transform(p_root, end_node,
					Transform(
						get_snapped_rotation(end_node_final_basis, p_snap_degrees),
						target_end_position
					)
				)
				
				# Special case for modifying the thumb
				# This is horrible, please forgive me
				if p_digit_id == avatar_constants_const.DIGIT_THUMB and ! p_roll_fix_pass:
					var gt: Transform = Transform()
					
					node_util_const.get_relative_global_transform(p_root, end_node)
					
					var end_node_parent: Node = end_node.get_parent()
					end_node_parent.remove_child(end_node)
					start_node.add_child(end_node)
					
					node_util_const.set_relative_global_transform(p_root, end_node, gt)
					if p_side == avatar_constants_const.SIDE_RIGHT:
						start_node.rotate_y(deg2rad(45))
					else:
						start_node.rotate_y(deg2rad(-45))
						
					end_node.set_owner(end_node_parent)
					
					gt = node_util_const.get_relative_global_transform(p_root, end_node)
					
					start_node.remove_child(end_node)
					end_node_parent.add_child(end_node)
					end_node.set_owner(end_node_parent)
					
					node_util_const.set_relative_global_transform(p_root, end_node, gt)
					
				ik.target_node = ik.get_path_to(end_node)
				
				p_custom_bone_pose_array = setup_bone_chain(p_skeleton, bone_chain, ik, p_custom_bone_pose_array)
				
				return {"custom_bone_pose_array":p_custom_bone_pose_array, "success":true}
				
	return {"custom_bone_pose_array":p_custom_bone_pose_array, "success":false}


func correct_hand_roll(
	p_side: int, p_skeleton: Skeleton, p_humanoid_data: humanoid_data_const, p_roll_fix_pass: bool
) -> float:
	print("correct_hand_roll")
	var start_id: int = -1
	var end_id: int = -1

	var start_name: String = ""
	var end_name: String = ""

	var hand: Hand = null

	if p_side == avatar_constants_const.SIDE_RIGHT:
		hand = right_hand
	else:
		hand = left_hand

	var index: Digit = hand.index
	var little: Digit = hand.little

	var index_bone_id: int = p_skeleton.find_bone(index.start_name)
	var little_bone_id: int = p_skeleton.find_bone(little.start_name)

	if index_bone_id != -1 and little_bone_id != -1:
		var index_global_pose: Transform = p_skeleton.get_bone_global_pose(index_bone_id)
		var little_global_pose: Transform = p_skeleton.get_bone_global_pose(little_bone_id)

		var source_origin: Vector2 = Vector2(index_global_pose.origin.y, index_global_pose.origin.z)
		var target_origin: Vector2 = Vector2(little_global_pose.origin.y, little_global_pose.origin.z)

		var target_angle: float = abs(source_origin.angle_to_point(target_origin))
		var angle_difference: float = deg2rad(90) - target_angle

		return angle_difference

	return 0.0


func correct_hand_pitch(
	p_side: int, p_skeleton: Skeleton, p_humanoid_data: humanoid_data_const, p_roll_fix_pass: bool
) -> float:
	print("correct_hand_pitch")
	var start_id: int = -1
	var end_id: int = -1

	var start_name: String = ""
	var end_name: String = ""

	var hand: Hand = null
	var hand_bone_id: int = -1

	if p_side == avatar_constants_const.SIDE_RIGHT:
		hand = right_hand
		hand_bone_id = p_skeleton.find_bone(right_arm_end_name)
	else:
		hand = left_hand
		hand_bone_id = p_skeleton.find_bone(left_arm_end_name)

	var index: Digit = hand.index
	var little: Digit = hand.little

	var index_bone_id: int = p_skeleton.find_bone(index.start_name)
	var little_bone_id: int = p_skeleton.find_bone(little.start_name)

	if index_bone_id != -1 and little_bone_id != -1 and hand_bone_id != -1:
		var index_global_pose: Transform = p_skeleton.get_bone_global_pose(index_bone_id)
		var little_global_pose: Transform = p_skeleton.get_bone_global_pose(little_bone_id)
		var hand_global_pose: Transform = p_skeleton.get_bone_global_pose(hand_bone_id)

		var source_origin: Vector2 = Vector2(hand_global_pose.origin.x, hand_global_pose.origin.y)
		var target_origin: Vector2 = Vector2(
			Vector2(index_global_pose.origin.x, index_global_pose.origin.y).linear_interpolate(
				Vector2(little_global_pose.origin.x, little_global_pose.origin.y), 0.5
			)
		)

		var target_angle: float = source_origin.angle_to_point(target_origin)
		var reference_angle: float = deg2rad(round(rad2deg(target_angle) / 90) * 90)

		var angle_difference: float = reference_angle - target_angle

		return angle_difference

	return 0.0


func straighten_side(p_root: Spatial,
	p_side: int,
	p_skeleton: Skeleton,
	p_humanoid_data: humanoid_data_const,
	p_roll_fix_pass: bool,
	p_custom_bone_pose_array: Array
) -> Dictionary:
	print("straighten_side")
	var arm_result: Dictionary = straighten_arm(p_root, p_side, p_skeleton, p_humanoid_data, p_roll_fix_pass, p_custom_bone_pose_array)
	
	p_custom_bone_pose_array = arm_result["custom_bone_pose_array"]
	
	if arm_result["success"]:
		var hand_basis: Basis = Basis()
		
		if p_side == avatar_constants_const.SIDE_LEFT:
			hand_basis = node_util_const.get_relative_global_transform(p_root, arm_end_left_point).basis
		else:
			hand_basis = node_util_const.get_relative_global_transform(p_root, arm_end_right_point).basis
			
		for i in range(avatar_constants_const.DIGIT_THUMB, avatar_constants_const.DIGIT_LITTLE + 1):
			if i == avatar_constants_const.DIGIT_THUMB:
				var thumb_result: Dictionary = straighten_digit(
					p_root,
					p_side,
					i,
					p_skeleton,
					p_humanoid_data,
					hand_basis,
					THUMB_SNAP_DEGREES,
					p_roll_fix_pass,
					p_custom_bone_pose_array
				)
				
				p_custom_bone_pose_array = thumb_result["custom_bone_pose_array"]
			else:
				var digit_result: Dictionary = straighten_digit(
					p_root,
					p_side,
					i,
					p_skeleton,
					p_humanoid_data,
					hand_basis,
					FINGER_SNAP_DEGREES,
					p_roll_fix_pass,
					p_custom_bone_pose_array
				)
				
				p_custom_bone_pose_array = digit_result["custom_bone_pose_array"]
	var leg_result: Dictionary = straighten_leg(p_root, p_side, p_skeleton, p_humanoid_data, p_roll_fix_pass, p_custom_bone_pose_array)
	
	p_custom_bone_pose_array = leg_result["custom_bone_pose_array"]
	
	return {"custom_bone_pose_array":p_custom_bone_pose_array}


func setup_ik_t_pose(
	p_root: Spatial,
	p_skeleton: Skeleton,
	p_humanoid_data: humanoid_data_const,
	p_is_roll_fix_pass: bool
) -> Dictionary:
	print("---Running IKPoseFixer---")
	
	# Saracen: this is a hack to get around a bug where the skeleton which was
	# recently duplicated is not updated correctly.
	p_skeleton.clear_bones_global_pose_override()
	var _root_global_pose = p_skeleton.get_bone_global_pose_without_override(0, true)
	
	destroy_points()

	var is_roll_fix_pass: bool = true

	left_hand = null
	right_hand = null
	
	# Build the custom bone pose array
	var custom_bone_pose_array: Array = []
	custom_bone_pose_array.resize(p_skeleton.get_bone_count())
		
	for bone_id in p_skeleton.get_bone_count():
		custom_bone_pose_array[bone_id] = Transform()
	#
	
	# Check for errors
	var err: int = avatar_callback_const.generic_error_check(p_root, p_skeleton)
	if err != avatar_callback_const.AVATAR_OK:
		return {
			"result":err,
			"custom_bone_pose_array":custom_bone_pose_array
			}
		
	var create_points_callback: int = create_points(p_root, p_skeleton, p_humanoid_data)
	
	if create_points_callback == avatar_callback_const.AVATAR_OK:
		print("Attempting to straighten spine...")
		var result: Dictionary = straighten_vertical(
			p_root,
			p_skeleton,
			p_humanoid_data,
			hips_point,
			spine_end_point,
			hips_name,
			spine_end_name,
			spine_ik,
			is_roll_fix_pass,
			custom_bone_pose_array
		)
		
		custom_bone_pose_array = result["custom_bone_pose_array"]
		
		print("Attempting to straighten neck...")
		result = straighten_vertical(
			p_root,
			p_skeleton,
			p_humanoid_data,
			neck_point,
			head_point,
			neck_name,
			head_name,
			neck_ik,
			is_roll_fix_pass,
			custom_bone_pose_array
		)
		
		custom_bone_pose_array = result["custom_bone_pose_array"]
		
		print("Attempting to straighten left side...")
		result = straighten_side(
			p_root,
			avatar_constants_const.SIDE_LEFT,
			p_skeleton,
			p_humanoid_data,
			is_roll_fix_pass,
			custom_bone_pose_array
		)
		
		custom_bone_pose_array = result["custom_bone_pose_array"]
		
		print("Attempting to straighten right side...")
		result = straighten_side(
			p_root,
			avatar_constants_const.SIDE_RIGHT,
			p_skeleton,
			p_humanoid_data,
			is_roll_fix_pass,
			custom_bone_pose_array
		)
		
		custom_bone_pose_array = result["custom_bone_pose_array"]
		
	else:
		return {
			"result":create_points_callback,
			"custom_bone_pose_array":custom_bone_pose_array
			}

	# Workaround: IK is using a global pose override so this clears it
	for i in range(0, p_skeleton.get_bone_count()):
		p_skeleton.set_bone_global_pose_override(i, Transform(), 0.0, false)

	if DELETE_HELPER_NODES:
		destroy_points()

	return {
		"result":avatar_callback_const.AVATAR_OK,
		"custom_bone_pose_array":custom_bone_pose_array
		}
