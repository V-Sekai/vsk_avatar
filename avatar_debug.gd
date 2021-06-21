extends Node

const gizmo_reference_const = preload("gizmo_reference.tscn")
const DEBUG_SCALE = 0.1

static func debug_bones(p_skeleton: Skeleton3D) -> void:
	for child in p_skeleton.get_children():
		if child.has_method("hide"):
			child.call("hide")
	
	for i in range(0, p_skeleton.get_bone_count()):
		var bone_name: String = p_skeleton.get_bone_name(i)
		
		var bone_attachment: BoneAttachment3D = BoneAttachment3D.new()
		bone_attachment.name = "attachment_" + bone_name
		
		p_skeleton.add_child(bone_attachment)
		
		bone_attachment.set_bone_name(bone_name)
		
		var gizmo_reference: Node3D = gizmo_reference_const.instantiate()
		bone_attachment.add_child(gizmo_reference)
		gizmo_reference.scale = Vector3.ONE * DEBUG_SCALE
		
