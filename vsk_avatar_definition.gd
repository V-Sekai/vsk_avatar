tool
extends "vsk_avatar_definition_runtime.gd"

var database_id: String = "" # Backwards compatibility
export(NodePath) var preview_camera_path: NodePath = NodePath()

export(Array, NodePath) var pipeline_paths = []

func add_pipeline(p_node: Node) -> void:
	pipeline_paths.push_back(get_path_to(p_node))
	
func remove_pipeline(p_node: Node) -> void:
	pipeline_paths.erase(get_path_to(p_node))

# Backwards compatibility
func _get_property_list():
    var properties = []
    properties.append(
        {
            name = "database_id",
            type = TYPE_STRING,
            usage = PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE
        }
    )
    return properties
