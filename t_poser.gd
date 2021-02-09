extends Node

const bone_lib_const = preload("res://addons/vsk_avatar/bone_lib.gd")
const math_funcs_const = preload("res://addons/math_util/math_funcs.gd")

const MAXIMUM_SPINE_TWIEST_DEGREES = 40.0

# Relative to spine
const MAXIMUM_HORIZINTAL_HIPS_DEGREES = 20.0
const MAXIMUM_VERTICAL_HIPS_DEGREES = 67.0

const MAXIMUM_VERTICAL_SHOULDER_DEGREES = 20.0
const MAXIMUM_HORIZONTAL_SHOULDER_DEGREES = 25.0

const MAXIMUM_TWIST_HIPS_TO_SPINE_DEGREES = 30.0

static func get_euler_angle_from_to(p_transform_start: Transform, p_transform_end: Transform) -> Vector3:
	var rotation: Transform = p_transform_start.looking_at(p_transform_end.origin, Vector3.UP)
	return rotation.basis.get_euler()
	
static func is_rotation_valid(p_rad_euler: Vector2, p_horizontal_max_rad: float, p_vertical_max_rad: float) -> bool:
	if abs(p_rad_euler.x) > p_vertical_max_rad:
		return false
		
	if abs(p_rad_euler.y) > p_horizontal_max_rad:
		return false
		
	return true
	
static func fix_rotation(p_rad_euler: Vector2, p_horizontal_max_rad: float, p_vertical_max_rad: float) -> Vector2:
	if abs(p_rad_euler.y) > p_horizontal_max_rad:
		p_rad_euler.y -= p_horizontal_max_rad * sign(p_rad_euler.y)
		
	if abs(p_rad_euler.x) > p_vertical_max_rad:
		p_rad_euler.x -= p_vertical_max_rad * sign(p_rad_euler.x)
	
	return p_rad_euler
		
static func get_rotation_error_for_direction(p_start: Transform, p_end: Transform, p_horizontal_max_rad: float, p_vertical_max_rad: float, p_direction: Vector3) -> Vector2:
	var rad_difference_vec3 = get_euler_angle_from_to(p_start, p_end)
	var rad_difference_vec2 = Vector2(rad_difference_vec3.x, rad_difference_vec3.y)

	# This rotation exceeds the maximum allowed for this pose
	if !is_rotation_valid(rad_difference_vec2, p_horizontal_max_rad, p_vertical_max_rad):
		rad_difference_vec2 = fix_rotation(rad_difference_vec2, p_horizontal_max_rad, p_vertical_max_rad)
		
		return rad_difference_vec2
	else:
		return Vector2()

static func get_relative_global_transform_for_bone(p_skeleton: Skeleton, p_root_bone_name: String, p_bone_name: String) -> Transform:
	# Stub
	return Transform()
