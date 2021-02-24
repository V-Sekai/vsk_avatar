extends Node

const VECTOR_DIRECTION = Vector3.UP

class RestBone extends Reference:
	var rest_local_before: Transform = Transform()
	var rest_local_after: Transform = Transform()
	var rest_delta: Quat = Quat()
	var children_centroid_direction: Vector3 = Vector3()
	var parent_index: int = -1
	var children: Array = []

static func _get_perpendicular_vector(p_v: Vector3) -> Vector3:
	var perpendicular: Vector3 = Vector3()
	if (p_v[0] != 0 and p_v[1] != 0):
		perpendicular = Vector3(0, 0, 1).cross(p_v).normalized()
	else:
		perpendicular = Vector3(1, 0, 0)
	
	return perpendicular
	
static func _align_vectors(a: Vector3, b: Vector3) -> Quat:
	a = a.normalized()
	b = b.normalized()
	if (a.length_squared() != 0.0 and b.length_squared() != 0.0):
		# Find the axis perpendicular to both vectors and rotate along it by the angular difference
		var perpendicular: Vector3 = a.cross(b).normalized()
		var angle_diff: float = a.angle_to(b)
		if (perpendicular.length_squared() == 0):
			perpendicular = _get_perpendicular_vector(a)
		return Quat(perpendicular, angle_diff)
	else:
		return Quat()

static func _fortune(p_skeleton: Skeleton, r_rest_bones: Dictionary) -> Dictionary:
	var bone_count: int = p_skeleton.get_bone_count()
	
	# First iterate through all the bones and create a RestBone for it with an empty centroid 
	for j in range(0, bone_count):
		var rest_bone: RestBone = RestBone.new()

		rest_bone.parent_index = p_skeleton.get_bone_parent(j)
		rest_bone.rest_local_before = p_skeleton.get_bone_rest(j)
		rest_bone.rest_local_after = rest_bone.rest_local_before
		r_rest_bones[j] = rest_bone
		

	# We iterate through again, and add the child's position to the centroid of its parent.
	# These position are local to the parent which means (0, 0, 0) is right where the parent is.
	for i in range(0, bone_count):
		var parent_bone: int = p_skeleton.get_bone_parent(i)
		if (parent_bone >= 0):
			r_rest_bones[parent_bone].children_centroid_direction = r_rest_bones[parent_bone].children_centroid_direction + p_skeleton.get_bone_rest(i).origin
			r_rest_bones[parent_bone].children.append(i)
			
	for i in range(0, bone_count):
		print(r_rest_bones[i].children_centroid_direction)
		print(r_rest_bones[i].children)
			

	# Point leaf bones to parent
	for i in range(0, bone_count):
		var leaf_bone: RestBone = r_rest_bones[i]
		if (leaf_bone.children.size() == 0):
			leaf_bone.children_centroid_direction = r_rest_bones[leaf_bone.parent_index].children_centroid_direction

	# We iterate again to point each bone to the centroid
	# When we rotate a bone, we also have to move all of its children in the opposite direction
	for i in range(0, bone_count):
		r_rest_bones[i].rest_delta = _align_vectors(VECTOR_DIRECTION, r_rest_bones[i].children_centroid_direction)
		r_rest_bones[i].rest_local_after.basis = r_rest_bones[i].rest_local_after.basis * Basis(r_rest_bones[i].rest_delta)

		# Iterate through the children and rotate them in the opposite direction.
		for j in range(0, r_rest_bones[i].children.size()):
			var child_index: int = r_rest_bones[i].children[j]
			r_rest_bones[child_index].rest_local_after = Transform(r_rest_bones[i].rest_delta.inverse(), Vector3()) * r_rest_bones[child_index].rest_local_after

	# One last iteration to apply the transforms we calculated
	for i in range(0, bone_count):
		p_skeleton.set_bone_rest(i, r_rest_bones[i].rest_local_after)
	
	return r_rest_bones

static func fix_skeleton(p_skeleton: Skeleton, _humanoid_data: HumanoidData) -> void:
	print("bone_direction: fix_skeleton")
	
	_fortune(p_skeleton, {})
