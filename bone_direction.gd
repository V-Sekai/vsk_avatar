extends Node

# GDScript implementation of a modified version of the fortune algorthim.
# Thanks to iFire, Lyuma, and MMMaellon for the C++ implementation this version was based off, saved me
# a lot of headaches ;)
# https://github.com/godot-extended-libraries/godot-fire/commit/622022d2779f9d35b586db4ee31c9cb76d0b7bc7

const avatar_lib_const = preload("avatar_lib.gd")
const bone_lib = preload("bone_lib.gd")

const VECTOR_DIRECTION = Vector3.UP

class RestBone extends RefCounted:
	var rest_local_before: Transform3D = Transform3D()
	var rest_local_after: Transform3D = Transform3D()
	var rest_delta: Quaternion = Quaternion()
	var children_centroid_direction: Vector3 = Vector3()
	var parent_index: int = -1
	var children: Array = []
	var override_direction: bool = true

static func _get_perpendicular_vector(p_v: Vector3) -> Vector3:
	var perpendicular: Vector3 = Vector3()
	if !is_zero_approx(p_v[0]) and !is_zero_approx(p_v[1]):
		perpendicular = Vector3(0, 0, 1).cross(p_v).normalized()
	else:
		perpendicular = Vector3(1, 0, 0)
	
	return perpendicular
	
static func _align_vectors(a: Vector3, b: Vector3) -> Quaternion:
	a = a.normalized()
	b = b.normalized()
	var angle: float = a.angle_to(b)
	if is_zero_approx(angle):
		return Quaternion()
	if !is_zero_approx(a.length_squared()) and !is_zero_approx(b.length_squared()):
		# Find the axis perpendicular to both vectors and rotate along it by the angular difference
		var perpendicular: Vector3 = a.cross(b).normalized()
		var angle_diff: float = a.angle_to(b)
		if is_zero_approx(perpendicular.length_squared()):
			perpendicular = _get_perpendicular_vector(a)
		return Quaternion(perpendicular, angle_diff)
	else:
		return Quaternion()

static func _fortune_with_chains(
	p_skeleton: Skeleton3D,
	r_rest_bones: Dictionary,
	p_fixed_chains: Array,
	p_ignore_unchained_bones: bool,
	p_ignore_chain_tips: Array,
	p_base_pose: Array) -> Dictionary:
	var bone_count: int = p_skeleton.get_bone_count()
	
	# First iterate through all the bones and create a RestBone for it with an empty centroid 
	for j in range(0, bone_count):
		var rest_bone: RestBone = RestBone.new()

		rest_bone.parent_index = p_skeleton.get_bone_parent(j)
		rest_bone.rest_local_before = p_base_pose[j]
		rest_bone.rest_local_after = rest_bone.rest_local_before
		r_rest_bones[j] = rest_bone
	
	# Collect all bone chains into a hash table for optimisation
	var chain_hash_table: Dictionary = {}.duplicate()
	for chain in p_fixed_chains:
		for bone_id in chain:
			chain_hash_table[bone_id] = chain

	# We iterate through again, and add the child's position to the centroid of its parent.
	# These position are local to the parent which means (0, 0, 0) is right where the parent is.
	for i in range(0, bone_count):
		var parent_bone: int = p_skeleton.get_bone_parent(i)
		if (parent_bone >= 0):
			
			var apply_centroid = true
			
			var chain = chain_hash_table.get(parent_bone, null)
			if typeof(chain) == TYPE_PACKED_INT32_ARRAY:
				var index: int = -1
				for findind in range(len(chain)):
					if chain[findind] == parent_bone:
						index = findind
				if (index + 1) < chain.size():
					# Check if child bone is the next bone in the chain
					if chain[index + 1] == i:
						apply_centroid = true
					else:
						apply_centroid = false
				else:
					# If the bone is at the end of a chain, p_ignore_chain_tips argument determines
					# whether it should attempt to be corrected or not
					if p_ignore_chain_tips.has(chain):
						r_rest_bones[parent_bone].override_direction = false
						apply_centroid = false
					else:
						apply_centroid = true
			else:
				if p_ignore_unchained_bones:
					r_rest_bones[parent_bone].override_direction = false
					apply_centroid = false
					
			if apply_centroid:
				r_rest_bones[parent_bone].children_centroid_direction = r_rest_bones[parent_bone].children_centroid_direction + p_skeleton.get_bone_rest(i).origin
			r_rest_bones[parent_bone].children.append(i)
			

	# Point leaf bones to parent
	for i in range(0, bone_count):
		var leaf_bone: RestBone = r_rest_bones[i]
		if (leaf_bone.children.size() == 0):
			if p_ignore_unchained_bones and !chain_hash_table.get(i, null):
				r_rest_bones[i].override_direction = false
			leaf_bone.children_centroid_direction = r_rest_bones[leaf_bone.parent_index].children_centroid_direction

	# We iterate again to point each bone to the centroid
	# When we rotate a bone, we also have to move all of its children in the opposite direction
	for i in range(0, bone_count):
		if r_rest_bones[i].override_direction:
			r_rest_bones[i].rest_delta = _align_vectors(VECTOR_DIRECTION, r_rest_bones[i].children_centroid_direction)
			r_rest_bones[i].rest_local_after.basis = r_rest_bones[i].rest_local_after.basis * Basis(r_rest_bones[i].rest_delta)

			# Iterate through the children and rotate them in the opposite direction.
			for j in range(0, r_rest_bones[i].children.size()):
				var child_index: int = r_rest_bones[i].children[j]
				r_rest_bones[child_index].rest_local_after = Transform3D(r_rest_bones[i].rest_delta.inverse(), Vector3()) * r_rest_bones[child_index].rest_local_after
	
	return r_rest_bones

static func _fix_meshes(p_bind_fix_array: Array, p_mesh_instances: Array) -> void:
	print("bone_direction: _fix_meshes")
	
	for mi in p_mesh_instances:
		var skin: Skin = mi.get_skin();
		if skin == null:
			continue
			
		skin = skin.duplicate()
		mi.set_skin(skin)
		var skeleton_path: NodePath = mi.get_skeleton_path()
		var node: Node = mi.get_node_or_null(skeleton_path)
		var skeleton: Skeleton3D = node
		for bind_i in range(0, skin.get_bind_count()):
			var bone_index:int  = skin.get_bind_bone(bind_i)
			if (bone_index == -1):
				var bind_name: String = skin.get_bind_name(bind_i)
				if bind_name.is_empty():
					continue
				bone_index = skeleton.find_bone(bind_name)
				
			if (bone_index == -1):
				continue
			skin.set_bind_pose(bind_i, p_bind_fix_array[bone_index] * skin.get_bind_pose(bind_i))
			
static func get_humanoid_chains(p_skeleton: Skeleton3D, p_humanoid_data: HumanoidData) -> Array:
	var chains: Array = [].duplicate() # <>< <>< ><> RED HERRING <>< <>< <><
	
	# Spine
	chains.append(avatar_lib_const.get_full_spine_chain(p_skeleton, p_humanoid_data))
	
	for side in range(\
	avatar_lib_const.avatar_constants_const.SIDE_LEFT,\
	avatar_lib_const.avatar_constants_const.SIDE_RIGHT + 1):
		# Arm
		chains.append(avatar_lib_const.get_arm_chain(p_skeleton, p_humanoid_data,side))
		# Leg
		chains.append(avatar_lib_const.get_leg_chain(p_skeleton, p_humanoid_data, side))
		
		# Digits
		for digit in range(avatar_lib_const.avatar_constants_const.DIGIT_THUMB,
			avatar_lib_const.avatar_constants_const.DIGIT_LITTLE + 1):
				chains.append(avatar_lib_const.get_digit_chain(\
					p_skeleton, p_humanoid_data, side, digit))
	
	return chains
	
static func print_chain_names(p_skeleton: Skeleton3D, p_chains: Array) -> void:
	var idx: int = 0
	for chain in p_chains:
		var bone_string: String = ""
		for bone_id in chain:
			bone_string += p_skeleton.get_bone_name(bone_id) + ", "
		
		print("Chain %s: %s" % [str(idx), bone_string])
		
		idx += 1
		
static func get_fortune_with_chain_offsets(p_skeleton: Skeleton3D, p_humanoid_data: HumanoidData, p_base_pose: Array) -> Dictionary:
	# Get the 5 bone chains necessary for a valid humanoid rig
	var humanoid_chains: Array 
	var rest_bones: Dictionary
	if p_humanoid_data:
		humanoid_chains = get_humanoid_chains(p_skeleton, p_humanoid_data)
		rest_bones = _fortune_with_chains(p_skeleton, {}.duplicate(), humanoid_chains, false, [humanoid_chains[0]], p_base_pose)
	else:
		rest_bones = _fortune_with_chains(p_skeleton, {}.duplicate(), [], false, [], p_base_pose)
	
	var offsets: Dictionary = {"base_pose_offsets":[], "bind_pose_offsets":[]}
	
	for key in rest_bones.keys():
		offsets["base_pose_offsets"].append(rest_bones[key].rest_local_before.inverse() * rest_bones[key].rest_local_after)
		offsets["bind_pose_offsets"].append(Transform3D(rest_bones[key].rest_delta.inverse()))
		
	return offsets

static func fix_skeleton(p_root: Node, p_skeleton: Skeleton3D, p_humanoid_data: HumanoidData, undo_redo: UndoRedo) -> void:
	print("bone_direction: fix_skeleton")
	
	var base_pose: Array = []
	for i in range(0, p_skeleton.get_bone_count()):
		base_pose.append(p_skeleton.get_bone_rest(i))
	
	var offsets: Dictionary = get_fortune_with_chain_offsets(p_skeleton, p_humanoid_data, base_pose)
	for i in range(0, offsets["base_pose_offsets"].size()):
		var final_pose: Transform3D = p_skeleton.get_bone_rest(i) * offsets["base_pose_offsets"][i]
		bone_lib.change_bone_rest(p_skeleton, i, final_pose)
	# Correct the bind poses
	var mesh_instances: Array = avatar_lib_const.find_mesh_instances_for_avatar_skeleton(p_root, p_skeleton, [])
	_fix_meshes(offsets["bind_pose_offsets"], mesh_instances)
