extends Node

static func find_mesh_instances_for_skeleton(p_node: Node, p_skeleton: Skeleton, p_valid_mesh_instances: Array) -> Array:
	if p_skeleton and p_node is MeshInstance:
		var skeleton: Node = p_node.get_node_or_null(p_node.skeleton)
		if skeleton == p_skeleton:
			p_valid_mesh_instances.push_back(p_node)
			
	for child in p_node.get_children():
		p_valid_mesh_instances = find_mesh_instances_for_skeleton(child, p_skeleton, p_valid_mesh_instances)
	
	return p_valid_mesh_instances
