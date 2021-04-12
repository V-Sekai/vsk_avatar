extends Reference
tool

enum {
	AVATAR_OK,
	AVATAR_FAILED,
	AVATAR_COULD_NOT_CREATE_POINTS,
	ROOT_IS_NULL,
	SKELETON_IS_NULL,
	SKELETON_ZERO_BONES,
	ROOT_NOT_PARENT_OF_SKELETON,
	ROOT_NOT_PARENT_OF_VISEME_MESH,
	NO_HUMANOID_DATA,
	HUMANOID_DATA_INVALID,
	NO_MUSCLE_DATA,
	SKIN_MESH_INSTANCE_SIZE_MISMATCH,
	AVATAR_COULD_NOT_SANITISE,
	
	AVATAR_SPINE_ROOT_MISSING,
	AVATAR_SPINE_TIP_MISSING,
	AVATAR_SPINE_BONES_MISORDERED,
	
	AVATAR_NECK_ROOT_MISSING,
	AVATAR_NECK_TIP_MISSING,
	AVATAR_NECK_BONES_MISORDERED,
	
	AVATAR_ARM_LEFT_ROOT_MISSING,
	AVATAR_ARM_LEFT_TIP_MISSING,
	AVATAR_ARM_LEFT_BONES_MISORDERED,
	
	AVATAR_ARM_RIGHT_ROOT_MISSING,
	AVATAR_ARM_RIGHT_TIP_MISSING,
	AVATAR_ARM_RIGHT_BONES_MISORDERED,
	
	AVATAR_LEG_LEFT_ROOT_MISSING,
	AVATAR_LEG_LEFT_TIP_MISSING,
	AVATAR_LEG_LEFT_BONES_MISORDERED,
	
	AVATAR_LEG_RIGHT_ROOT_MISSING,
	AVATAR_LEG_RIGHT_TIP_MISSING,
	AVATAR_LEG_RIGHT_BONES_MISORDERED,
	
	EXPORTER_NOT_LOADED,
}

static func get_error_string(p_err: int) -> String:
	var error_string: String = "Unknown error!"
	match p_err:
		AVATAR_FAILED:
			error_string = "Generic avatar error! (complain to Saracen)"
		AVATAR_COULD_NOT_CREATE_POINTS:
			error_string = "Could not create points required for IK remapping! (Probably missing humanoid data)"
		ROOT_IS_NULL:
			error_string = "Root node is null!"
		SKELETON_IS_NULL:
			error_string = "Humanoid avatar requires a skeleton to be assigned!"
		ROOT_NOT_PARENT_OF_SKELETON:
			error_string = "Skeleton is not a child of the root node!"
		ROOT_NOT_PARENT_OF_VISEME_MESH:
			error_string = "Viseme mesh is not a child of the root node!"
		NO_HUMANOID_DATA:
			error_string = "Humanoid avatars require HumanoidData resource!"
		HUMANOID_DATA_INVALID:
			error_string = "Avatar HumanoidData is invalid!"
		NO_MUSCLE_DATA:
			error_string = "Humanoid avatars require MuscleData resource!"
		SKIN_MESH_INSTANCE_SIZE_MISMATCH:
			error_string = "The number of Skin resources do not match the number of MeshInstances!"
		AVATAR_COULD_NOT_SANITISE:
			error_string = "Could not remove forbidden nodes in avatar!"
			
		AVATAR_SPINE_ROOT_MISSING:
			error_string = "Spine root missing!"
		AVATAR_SPINE_TIP_MISSING:
			error_string = "Spine tip missing!"
		AVATAR_SPINE_BONES_MISORDERED:
			error_string = "Spine chain misordered!"
		
		AVATAR_NECK_ROOT_MISSING:
			error_string = "Neck root missing!"
		AVATAR_NECK_TIP_MISSING:
			error_string = "Neck tip missing!"
		AVATAR_NECK_BONES_MISORDERED:
			error_string = "Neck chain misordered!"
		
		AVATAR_ARM_LEFT_ROOT_MISSING:
			error_string = "Arm Left root missing!"
		AVATAR_ARM_LEFT_TIP_MISSING:
			error_string = "Arm Left tip missing!"
		AVATAR_ARM_LEFT_BONES_MISORDERED:
			error_string = "Arm Left chain misordered!"
		
		AVATAR_ARM_RIGHT_ROOT_MISSING:
			error_string = "Arm Right root missing!"
		AVATAR_ARM_RIGHT_TIP_MISSING:
			error_string = "Arm Right tip missing!"
		AVATAR_ARM_RIGHT_BONES_MISORDERED:
			error_string = "Arm Right chain misordered!"
		
		AVATAR_LEG_LEFT_ROOT_MISSING:
			error_string = "Leg Left root missing!"
		AVATAR_LEG_LEFT_TIP_MISSING:
			error_string = "Leg Left tip missing!"
		AVATAR_LEG_LEFT_BONES_MISORDERED:
			error_string = "Leg Left chain misordered!"
		
		AVATAR_LEG_RIGHT_ROOT_MISSING:
			error_string = "Leg Right root missing!"
		AVATAR_LEG_RIGHT_TIP_MISSING:
			error_string = "Leg Right tip missing!"
		AVATAR_LEG_RIGHT_BONES_MISORDERED:
			error_string = "Leg Right chain misordered!"
		EXPORTER_NOT_LOADED:
			error_string = "Exporter not loaded!"
	
	return error_string

static func generic_error_check(p_root: Spatial, p_skeleton: Skeleton) -> int:
	if p_root == null:
		return ROOT_IS_NULL
		
	if p_skeleton == null:
		return SKELETON_IS_NULL
		
	if p_skeleton.get_bone_count() <= 0:
		return SKELETON_ZERO_BONES
		
	if ! p_root.is_a_parent_of(p_skeleton):
		return ROOT_NOT_PARENT_OF_SKELETON
		
	return AVATAR_OK
