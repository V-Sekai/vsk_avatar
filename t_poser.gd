extends Node

const node_util_const = preload("res://addons/gd_util/node_util.gd")
const bone_lib_const = preload("res://addons/vsk_avatar/bone_lib.gd")
const math_funcs_const = preload("res://addons/math_util/math_funcs.gd")
const avatar_lib_const = preload("avatar_lib.gd")

const TARGET_THRESHOLD = 1.0

const MAXIMUM_SPINE_TWIST_DEGREES = 40.0

# Relative to spine
const MAXIMUM_HORIZINTAL_HIPS_DEGREES = 20.0
const MAXIMUM_VERTICAL_HIPS_DEGREES = 67.0

const MAXIMUM_VERTICAL_SHOULDER_DEGREES = 20.0
const MAXIMUM_HORIZONTAL_SHOULDER_DEGREES = 25.0

const MAXIMUM_HORIZONTAL_UPPER_ARM_DEGREES = 5.0
const MAXIMUM_VERTICAL_UPPER_ARM_DEGREES = 5.0

const MAXIMUM_HORIZONTAL_LOWER_ARM_DEGREES = 3.0
const MAXIMUM_VERTICAL_LOWER_ARM_DEGREES = 3.0

const MAXIMUM_VERTICAL_UPPER_LEG_DEGREES = 15.0
const MAXIMUM_HORIZONTAL_UPPER_LEG_DEGREES = 15.0

const MAXIMUM_TWIST_HIPS_TO_SPINE_DEGREES = 30.0

static func get_basis_rotated_towards_normal(p_basis: Basis, p_target_normal: Vector3) -> Basis:
	var y_dir = p_basis.y.normalized()
	var angle: float = y_dir.angle_to(p_target_normal)
	if (is_zero_approx(angle) ||
			y_dir.normalized().is_equal_approx(p_target_normal.normalized()) ||
			y_dir.normalized().is_equal_approx(-p_target_normal.normalized())):
		return Basis.IDENTITY
	var cross_product: Vector3 = y_dir.cross(p_target_normal).normalized()
	
	return Basis(cross_product, angle) * p_basis
	
static func get_length_for_transform_array(p_transforms: Array) -> float:
	var length: float = 0.0
	var current: int = -1
	var last: int = -1
	
	for i in range(0, p_transforms.size()):
		last = current
		current = i
		if last != -1:
			var current_transform: Transform3D = p_transforms[current]
			var last_transform: Transform3D = p_transforms[last]

			length += current_transform.origin.distance_to(last_transform.origin)
			
	return length

static func get_chain_length(p_skeleton: Skeleton3D, p_chain: Array, p_rest_transform_array: Array, p_pose_transform_array: Array) -> float:
	# Get the overall length of the chain
	var original_gt_array: Array = []
	for bone_id in p_chain:
		original_gt_array.push_back(bone_lib_const.get_bone_global_transform(bone_id, p_skeleton, [p_rest_transform_array, p_pose_transform_array]))
	
	var chain_length: float = get_length_for_transform_array(original_gt_array)
	
	return chain_length
	

static func straighten_chain(p_skeleton: Skeleton3D, p_direction: Vector3, p_chain: PackedInt32Array, p_rest_transform_array: Array, p_t_pose_transform_array: Array, p_inverse_children: bool) -> Array:
	#print("STRAIGHTEN_CHAIN")
	
	for bone_id in p_chain:
		#print("chain bone id: " + str(bone_id))
		
		var bone_gt: Transform3D = bone_lib_const.get_bone_global_transform(bone_id, p_skeleton, [p_rest_transform_array, p_t_pose_transform_array])
		var corrected_bone_gt: Transform3D = Transform3D(get_basis_rotated_towards_normal(bone_gt.basis, p_direction), bone_gt.origin)
		
		var bone_parent_id: int = p_skeleton.get_bone_parent(bone_id)
		if bone_parent_id != -1:
			var parent_bone_gt: Transform3D = bone_lib_const.get_bone_global_transform(bone_parent_id, p_skeleton, [p_rest_transform_array, p_t_pose_transform_array])
			p_t_pose_transform_array[bone_id] = (parent_bone_gt * p_rest_transform_array[bone_id]).inverse() * corrected_bone_gt
		else:
			p_t_pose_transform_array[bone_id] = p_rest_transform_array[bone_id].inverse() * corrected_bone_gt
		
		# Apply the inverse to all the bones not in this chain
		if p_inverse_children:
			var bone_rest_gt: Transform3D = bone_lib_const.get_bone_global_transform(bone_id, p_skeleton, [p_rest_transform_array])
			for child_id in p_skeleton.get_bone_children(bone_id):
				if !p_chain.has(child_id):
					var child_rest_transform : Transform3D = p_rest_transform_array[child_id]
					p_t_pose_transform_array[child_id] *= (corrected_bone_gt * child_rest_transform).inverse() * (bone_rest_gt * child_rest_transform)
	
	return p_t_pose_transform_array


static func get_direction_for_humanoid_bone(p_humanoid_data: HumanoidData, p_skeleton: Skeleton3D, p_humanoid_bone: int) -> Vector3:
	var bone_idx: int = p_humanoid_data.find_skeleton_bone_for_humanoid_bone(p_skeleton, p_humanoid_bone)
	var bone_gt: Transform3D = p_skeleton.get_bone_global_pose(bone_idx)
	
	return Vector3()

static func get_strict_t_pose(p_root: Node, p_skeleton: Skeleton3D, p_humanoid_data: HumanoidData, p_base_pose_array: Array) -> Array:
	var t_pose_transform_array: Array = []
	
	var base_transform: Transform3D = node_util_const.get_relative_global_transform(p_root, p_skeleton)
	
	for _i in range(0, p_skeleton.get_bone_count()):
		t_pose_transform_array.push_back(Transform3D())
		
	# Correct any root bones between the root and hip
	t_pose_transform_array = straighten_chain(
		p_skeleton,
		base_transform * Vector3.UP,
		avatar_lib_const.get_root_chain(p_skeleton, p_humanoid_data),
		p_base_pose_array,
		t_pose_transform_array,
		true)
	
	t_pose_transform_array = straighten_chain(
		p_skeleton,
		base_transform * Vector3.UP,
		avatar_lib_const.get_spine_chain(p_skeleton, p_humanoid_data),
		p_base_pose_array,
		t_pose_transform_array,
		true)
	
	for side in range(avatar_lib_const.avatar_constants_const.SIDE_LEFT, avatar_lib_const.avatar_constants_const.SIDE_RIGHT+1):
		t_pose_transform_array = straighten_chain(
			p_skeleton,
			base_transform * Vector3.DOWN,
			avatar_lib_const.get_leg_chain(p_skeleton, p_humanoid_data, side),
			p_base_pose_array,
			t_pose_transform_array,
			true)
		
			
		var side_direction: Vector3 = Vector3()
		match side:
			avatar_lib_const.avatar_constants_const.SIDE_LEFT:
				side_direction = base_transform * -Vector3.LEFT
			avatar_lib_const.avatar_constants_const.SIDE_RIGHT:
				side_direction = base_transform * -Vector3.RIGHT
				
		t_pose_transform_array = straighten_chain(
			p_skeleton,
			side_direction,
			avatar_lib_const.get_arm_chain(p_skeleton, p_humanoid_data, side),
			p_base_pose_array,
			t_pose_transform_array,
			true)
			
		for digit in range(avatar_lib_const.avatar_constants_const.DIGIT_THUMB, avatar_lib_const.avatar_constants_const.DIGIT_LITTLE+1):
			t_pose_transform_array = straighten_chain(
				p_skeleton,
				side_direction,
				avatar_lib_const.get_digit_chain(p_skeleton, p_humanoid_data, side, digit),
				p_base_pose_array,
				t_pose_transform_array,
				true)
	
	return t_pose_transform_array

static func enforce_strict_t_pose(p_root: Node, p_skeleton: Skeleton3D, p_humanoid_data: HumanoidData, p_base_pose_array: Array) -> void:
	for i in range(0, p_skeleton.get_bone_count()):
		p_skeleton.set_bone_pose_rotation(i, p_skeleton.get_bone_rest(i).basis.get_rotation_quaternion())
	
	var t_pose_rotations: Array = get_strict_t_pose(p_root, p_skeleton, p_humanoid_data, p_base_pose_array)
		
	for i in range(0, p_skeleton.get_bone_count()):
		p_skeleton.set_bone_pose_rotation(i, t_pose_rotations[i].basis.get_rotation_quaternion())
