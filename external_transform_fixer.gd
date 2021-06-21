@tool
extends RefCounted

const avatar_callback_const = preload("avatar_callback.gd")

static func fix_external_transform(p_root: Node, p_skeleton: Skeleton3D) -> int:
	print("---Running ExternalTransform3DFixer---")
	
	var err: int = avatar_callback_const.generic_error_check(p_root, p_skeleton)
	if err != avatar_callback_const.AVATAR_OK:
		return err
		
	var skeleton_parent_array: Array = []
	var node: Node = p_skeleton
	while(node != p_root):
		skeleton_parent_array.push_front(node)
		node = node.get_parent()
			
	var external_transform: Transform3D = Transform3D()
	for entry in skeleton_parent_array:
		external_transform *= entry.transform
		if entry is Node3D:
			entry.transform = Transform3D()
			for child in entry.get_children():
				if ! skeleton_parent_array.has(child):
					# Do not apply transform to skeleton's bone attachments
					# but apply to its children
					if child is BoneAttachment and child.get_parent() == p_skeleton:
						printerr("BoneAttachments are still funky, complain to Saracen!")
						continue
						
					# Do not apply transform to any meshes with the skeleton
					# set the skeleton's who's parent's we're fixing
					if child is MeshInstance3D:
						if child.get_node_or_null(child.skeleton) == p_skeleton:
							continue
						
					if child is Node3D:
						child.transform = external_transform * child.transform
		
	p_skeleton.set_bone_rest(0, external_transform * p_skeleton.get_bone_rest(0))
	
	return avatar_callback_const.AVATAR_OK
