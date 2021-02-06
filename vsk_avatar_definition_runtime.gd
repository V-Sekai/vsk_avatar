extends Spatial
tool

const humanoid_data_const = preload("humanoid_data.gd")

export(NodePath) var skeleton_path : NodePath = NodePath() setget set_skeleton_path
var _skeleton_node : Skeleton = null

export(NodePath) var eye_transform_node_path : NodePath = NodePath()
onready var _eye_transform_node : Spatial = get_node_or_null(eye_transform_node_path)

export(NodePath) var mouth_transform_node_path : NodePath = NodePath()
onready var _mouth_transform_node : Spatial = get_node_or_null(mouth_transform_node_path)

var humanoid_data : HumanoidData = null setget set_humanoid_data

func _get_property_list() -> Array:
	var property_list : Array = []
	
	property_list.push_back({"name":"humanoid_data", "type":TYPE_OBJECT, "hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string":"HumanoidData"})
	
	return property_list


func set_humanoid_data(p_humanoid_data : HumanoidData) -> void:
	if p_humanoid_data is humanoid_data_const:
		humanoid_data = p_humanoid_data


func set_eye_transform_path(p_node_path: NodePath) -> void:
	eye_transform_node_path = p_node_path


func set_mouth_transform_path(p_node_path: NodePath) -> void:
	mouth_transform_node_path = p_node_path


func set_skeleton_path(p_skeleton_path : NodePath) -> void:
	skeleton_path = p_skeleton_path
	_skeleton_node = null
	
	var skeleton_node : Skeleton = get_node_or_null(skeleton_path)
	if skeleton_node is Skeleton:
		_skeleton_node = skeleton_node
	else:
		_skeleton_node = null
			
	property_list_changed_notify()

func _ready() -> void:
	set_skeleton_path(skeleton_path)
