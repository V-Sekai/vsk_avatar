extends Node


static func get_runtime_info_mesh(p_mesh: Mesh, p_dictionary: Dictionary = {}) -> Dictionary:
	p_dictionary["MeshCount"] += 1
	
	var surface_count: int = p_mesh.get_surface_count()
	
	return p_dictionary

static func get_runtime_avatar_info_for_node(p_node: Node, p_dictionary: Dictionary = {}) -> Dictionary:
	if p_node is MeshInstance:
		p_dictionary["MeshInstanceCount"] += 1
		if p_node.skin:
			p_dictionary["MeshInstanceWithSkinCount"] += 1
		
		
	if p_node is Particles:
		p_dictionary["ParticleEmitterCount"] += 1
	
	if p_node is CPUParticles:
		p_dictionary["CPUParticleEmitterCount"] += 1
	
	for node in p_node.get_children():
		p_dictionary = get_runtime_avatar_info_for_node(p_node, p_dictionary)
		
	return p_dictionary
