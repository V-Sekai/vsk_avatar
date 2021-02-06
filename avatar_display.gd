extends Spatial
tool

const node_util_const = preload("res://addons/gdutil/node_util.gd")

const player_camera_controller_const = preload("res://addons/actor/player_camera_controller.gd")

const avatar_definition_const = preload("vsk_avatar_definition.gd")
const avatar_definition_runtime_const = preload("vsk_avatar_definition_runtime.gd")

const humanoid_data_const = preload("humanoid_data.gd")
const gizmo_reference_const = preload("gizmo_reference.tscn")

const attachment_point_3d_const = preload("res://addons/entity_manager/attachment_point_3d.gd")
const vr_constants_const = preload("res://addons/vr_manager/vr_constants.gd")

signal avatar_changed

var simulation_logic: Node = null

# Ugly workaround for limitations of the IK system
# Deals with the fact that shrinking the head and then
# writing out transforms call result in determinant
# errors
var saved_head_transform: Transform = Transform()

var use_wristspan_ratio: bool = false
var avatar_eye_height: float = 0.0
var avatar_wristspan: float = 0.0
var height_offset: float = 0.0

var humanoid_data: humanoid_data_const = null
var avatar_skeleton: Skeleton = null
var voice_player: Node = null

# The transform of the voice player relative the head bone
var relative_mouth_transform: Transform = Transform()

var head_id: int = -1
var hip_id: int = -1
var left_hand_id: int = -1
var right_hand_id: int = -1
var left_foot_id: int = -1
var right_foot_id: int = -1

var head_bone_attachment: BoneAttachment = null
var left_hand_bone_attachment: BoneAttachment = null
var right_hand_bone_attachment: BoneAttachment = null

enum shrink_enum {
	DETERMINED_BY_VIEW = 0,
	SHRINK,
	UNSHRINK
}

export (int, "Determined by View", "Shrink", "Unshrink") var shrink_mode = false
export (float) var default_avatar_height = 1.8
export (NodePath) var _ren_ik_path: NodePath = NodePath()
export (NodePath) var _ik_space_path: NodePath = NodePath()
export (NodePath) var player_camera_controller_path: NodePath = NodePath()
export (NodePath) var player_input_path: NodePath = NodePath()
export (NodePath) var voice_player_path: NodePath

var _ik_space: Node = null
var _player_camera_controller: Node = null

var avatar_pending: bool = false
var avatar_node: Spatial = null
var avatar_path: String = ""
var avatar_packed_scene: PackedScene = null

const bone_lib_const = preload("res://addons/vsk_avatar/bone_lib.gd")

const VISUALISE_ATTACHMENTS = false

const AVATAR_BASIS = Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0))
# This is totally abitrary, please find a better way to calculate this
const AVATAR_LOWER_DISTANCE = 0.05

func load_error_avatar() -> void:
	clear_avatar()
	set_avatar_model_path(VSKAssetManager.avatar_error_path)
	load_model(true)

func get_avatar_model_path() -> String:
	return avatar_path


func set_avatar_model_path(p_path: String) -> void:
	if avatar_path != p_path:
		if avatar_path != "":
			VSKAvatarManager.cancel_avatar(avatar_path)

		avatar_path = p_path


func clear_avatar() -> void:
	if avatar_node:
		setup_bone_attachments(null, null)
		avatar_node.queue_free()
		avatar_node.get_parent().remove_child(avatar_node)
		avatar_node = null


func _avatar_load_finished() -> void:
	VSKAvatarManager.disconnect("avatar_load_succeeded", self, "_avatar_load_succeeded")
	VSKAvatarManager.disconnect("avatar_load_failed", self, "_avatar_load_failed")

	avatar_pending = false


func _avatar_load_succeeded(p_url: String, p_packed_scene: PackedScene) -> void:
	var url_is_loading_avatar: bool = p_url == VSKAssetManager.loading_avatar_path
	
	if avatar_pending and (p_url == avatar_path or url_is_loading_avatar):
		if avatar_packed_scene != p_packed_scene:
			avatar_packed_scene = p_packed_scene
			if ! url_is_loading_avatar:
				_avatar_load_finished()
			call_deferred("_instance_avatar")


func _avatar_load_failed(p_url: String, p_err: int) -> void:
	printerr("Avatar load failed with error code: %s" % str(p_err))
	if avatar_pending and p_url == avatar_path:
		_avatar_load_finished()
		
		if p_url != VSKAssetManager.avatar_error_path:
			load_error_avatar()
		else:
			clear_avatar()
			printerr("Could not load failed avatar!")

func _instance_avatar() -> void:
	if is_inside_tree():
		if avatar_packed_scene:
			clear_avatar()

			var new_avatar_node: Spatial = avatar_packed_scene.instance()
			setup_avatar_instance(new_avatar_node)
			
			avatar_packed_scene = null

func _update_voice_player() -> void:
	if voice_player:
		if voice_player.get_parent() != head_bone_attachment:
			if voice_player.is_inside_tree():
				voice_player.get_parent().remove_child(voice_player)
		
			head_bone_attachment.add_child(voice_player)
		voice_player.transform = relative_mouth_transform * Transform().rotated(Vector3(0.0, 1.0, 0.0), PI)

func load_model(p_bypass_whitelist: bool) -> void:
	if ! avatar_pending:
		if VSKAvatarManager.connect("avatar_load_succeeded", self, "_avatar_load_succeeded") != OK:
			printerr("Could not connect 'avatar_load_succeeded'!")
		if VSKAvatarManager.connect("avatar_load_failed", self, "_avatar_load_failed") != OK:
			printerr("Could not connect 'avatar_load_failed'!")

		avatar_pending = true
	VSKAvatarManager.call_deferred("request_avatar", avatar_path, p_bypass_whitelist)


func setup_bone_attachments(p_humanoid_data: humanoid_data_const, p_skeleton: Skeleton) -> void:
	head_bone_attachment.get_parent().remove_child(head_bone_attachment)
	left_hand_bone_attachment.get_parent().remove_child(left_hand_bone_attachment)
	right_hand_bone_attachment.get_parent().remove_child(right_hand_bone_attachment)

	if p_skeleton and p_humanoid_data:
		var head_bone_id: int = p_skeleton.find_bone(p_humanoid_data.head_bone_name)
		var left_bone_id: int = p_skeleton.find_bone(p_humanoid_data.hand_left_bone_name)
		var right_bone_id: int = p_skeleton.find_bone(p_humanoid_data.hand_right_bone_name)

		if head_bone_id != -1:
			p_skeleton.add_child(head_bone_attachment)
			head_bone_attachment.bone_name = p_humanoid_data.head_bone_name
		else:
			add_child(head_bone_attachment)
		if left_bone_id != -1:
			p_skeleton.add_child(left_hand_bone_attachment)
			left_hand_bone_attachment.bone_name = p_humanoid_data.hand_left_bone_name
		else:
			add_child(left_hand_bone_attachment)
		if right_bone_id != -1:
			p_skeleton.add_child(right_hand_bone_attachment)
			right_hand_bone_attachment.bone_name = p_humanoid_data.hand_right_bone_name
		else:
			add_child(right_hand_bone_attachment)
	else:
		add_child(head_bone_attachment)
		add_child(left_hand_bone_attachment)
		add_child(right_hand_bone_attachment)


func create_bone_attachments() -> void:
	head_bone_attachment = BoneAttachment.new()
	left_hand_bone_attachment = BoneAttachment.new()
	right_hand_bone_attachment = BoneAttachment.new()
	
	head_bone_attachment.set_name("HeadAttachmentPoint")
	left_hand_bone_attachment.set_name("LeftHandAttachmentPoint")
	right_hand_bone_attachment.set_name("RightHandAttachmentPoint")

	head_bone_attachment.set_script(attachment_point_3d_const)
	left_hand_bone_attachment.set_script(attachment_point_3d_const)
	right_hand_bone_attachment.set_script(attachment_point_3d_const)

	var entity_node: Spatial = simulation_logic.get_entity_node()
	if entity_node == null:
		printerr("Entity node could not be found!")

	head_bone_attachment.set_entity(entity_node)
	left_hand_bone_attachment.set_entity(entity_node)
	right_hand_bone_attachment.set_entity(entity_node)

	add_child(head_bone_attachment)
	add_child(left_hand_bone_attachment)
	add_child(right_hand_bone_attachment)

	if VISUALISE_ATTACHMENTS:
		head_bone_attachment.add_child(gizmo_reference_const.instance())
		left_hand_bone_attachment.add_child(gizmo_reference_const.instance())
		right_hand_bone_attachment.add_child(gizmo_reference_const.instance())

func assign_ik_bone_assignments(
	p_ren_ik_node: Node, p_skeleton: Skeleton, p_humanoid_data: humanoid_data_const
) -> void:
	head_id = p_skeleton.find_bone(p_humanoid_data.head_bone_name)
	hip_id = p_skeleton.find_bone(p_humanoid_data.hips_bone_name)
	left_hand_id = p_skeleton.find_bone(p_humanoid_data.hand_left_bone_name)
	right_hand_id = p_skeleton.find_bone(p_humanoid_data.hand_right_bone_name)
	left_foot_id = p_skeleton.find_bone(p_humanoid_data.foot_left_bone_name)
	right_foot_id = p_skeleton.find_bone(p_humanoid_data.foot_right_bone_name)

	p_ren_ik_node.set_head_bone(head_id)
	p_ren_ik_node.set_hip_bone(hip_id)
	p_ren_ik_node.set_hand_left_bone(left_hand_id)
	p_ren_ik_node.set_hand_right_bone(right_hand_id)
	p_ren_ik_node.set_foot_left_bone(left_foot_id)
	p_ren_ik_node.set_foot_right_bone(right_foot_id)


func calculate_proportions() -> void:
	if VRManager.is_xr_active():
		var player_height = VRManager.vr_user_preferences.custom_player_height
		var origin_height_scale_offset: float = (
			(avatar_eye_height + vr_constants_const.EYE_TO_TOP_OF_HEAD)
			/ VRManager.vr_user_preferences.custom_player_height
		)
		var player_wrist_length = (
			VRManager.vr_user_preferences.custom_player_height
			* VRManager.vr_user_preferences.custom_player_armspan_to_height_ratio
			* vr_constants_const.ARMSPAN_WRIST_SPAN_CONVERSION
		)
		var origin_wrist_scale_offset: float = avatar_wristspan / player_wrist_length

		VRManager.set_origin_world_scale(lerp(
			origin_height_scale_offset, origin_wrist_scale_offset, VRManager.vr_user_preferences.eye_to_arm_ratio
		))
		var stilts: float = (
			(player_height * origin_height_scale_offset)
			- (player_height * origin_wrist_scale_offset)
		)
		height_offset = lerp(0.0, stilts, VRManager.vr_user_preferences.eye_to_arm_ratio)
	else:
		height_offset = 0.0
		avatar_eye_height = 0.0
		avatar_wristspan = 0.0
		VRManager.set_origin_world_scale(1.0)
		


func setup_avatar_instance(p_avatar_node: Spatial) -> void:
	avatar_skeleton = null

	var player_input_node: Node = get_node_or_null(player_input_path)
	if player_input_node:
		player_input_node.camera_height = default_avatar_height

	if p_avatar_node and (\
		p_avatar_node.get_script() == avatar_definition_const or\
		p_avatar_node.get_script() == avatar_definition_runtime_const):
		
		avatar_node = p_avatar_node
		add_child(avatar_node)

		# Get the skeleton and humanoid data
		humanoid_data = p_avatar_node.humanoid_data as humanoid_data_const
		var skeleton: Skeleton = (
			p_avatar_node.get_node_or_null(avatar_node.skeleton_path) as Skeleton
		)

		# Eye
		var eye_spatial: Spatial = avatar_node.get_node_or_null(avatar_node.eye_transform_node_path)
		var eye_global_transform: Transform
		if eye_spatial:
			# Get the global transform of the eye relative to the avatar root
			eye_global_transform = node_util_const.get_relative_global_transform(avatar_node, eye_spatial)
		else:
			var found_eyes: bool = false
			if skeleton and humanoid_data:
				var eye_left_bone_name: String = humanoid_data.eye_left_bone_name
				var eye_right_bone_name: String = humanoid_data.eye_right_bone_name
				
				var eye_left_bone_id: int = skeleton.find_bone(eye_left_bone_name)
				var eye_right_bone_id: int = skeleton.find_bone(eye_right_bone_name)
				
				if eye_left_bone_id != -1 and eye_right_bone_id != -1:
					var eye_left_global_transform: Transform = bone_lib_const.get_bone_global_rest_transform(eye_left_bone_id, skeleton)
					var eye_right_global_transform: Transform = bone_lib_const.get_bone_global_rest_transform(eye_right_bone_id, skeleton)
					
					eye_global_transform =\
					node_util_const.get_relative_global_transform(avatar_node, skeleton)\
					* eye_left_global_transform.interpolate_with(eye_right_global_transform, 0.5)
					
					found_eyes = true
				
			if !found_eyes:
				eye_global_transform = Transform(Basis(), Vector3(0.0, 1.0, 0.0) * (default_avatar_height - vr_constants_const.EYE_TO_TOP_OF_HEAD))
			
		eye_global_transform = Transform(Basis(), eye_global_transform.origin)
			
		avatar_eye_height = eye_global_transform.origin.y
		if player_input_node:
			player_input_node.camera_height = eye_global_transform.origin.y - AVATAR_LOWER_DISTANCE

		var eye_offset_transform: Transform = Transform()

		if humanoid_data and skeleton:
			avatar_node.set_as_toplevel(true)
			avatar_node.set_global_transform(Transform(AVATAR_BASIS, Vector3()))
			var head_bone_name: String = humanoid_data.head_bone_name
			var head_bone_id: int = skeleton.find_bone(head_bone_name)
			if head_bone_id != -1:
				var head_global_rest_transfrom: Transform = \
				node_util_const.get_relative_global_transform(avatar_node, skeleton)\
				* bone_lib_const.get_bone_global_rest_transform(head_bone_id, skeleton)
				eye_offset_transform = (
					eye_global_transform
					* head_global_rest_transfrom.inverse()
				)

			var left_hand_bone_name_id: int = skeleton.find_bone(humanoid_data.hand_left_bone_name)
			var right_hand_bone_name_id: int = skeleton.find_bone(
				humanoid_data.hand_right_bone_name
			)

			if left_hand_bone_name_id != -1 and right_hand_bone_name_id != -1:
				var left_wrist_transform: Transform = bone_lib_const.get_bone_global_rest_transform(
					left_hand_bone_name_id, skeleton
				)
				var right_wrist_transform: Transform = bone_lib_const.get_bone_global_rest_transform(
					right_hand_bone_name_id, skeleton
				)
				avatar_wristspan = left_wrist_transform.origin.distance_to(
					right_wrist_transform.origin
				)
		else:
			avatar_node.set_transform(Transform(AVATAR_BASIS, Vector3()))
			avatar_node.set_as_toplevel(false)
			avatar_wristspan = (VRManager.vr_user_preferences.custom_player_height
			* VRManager.vr_user_preferences.custom_player_armspan_to_height_ratio
			* vr_constants_const.ARMSPAN_WRIST_SPAN_CONVERSION)
				
		var ren_ik: Node = get_node_or_null(_ren_ik_path)
		if ren_ik and _ik_space:
			_ik_space.eye_offset = eye_offset_transform.origin
			avatar_skeleton = avatar_node.get_node_or_null(avatar_node.skeleton_path)
			if avatar_skeleton:
				ren_ik.set("armature_skeleton_path", ren_ik.get_path_to(avatar_skeleton))
				assign_ik_bone_assignments(ren_ik, avatar_skeleton, avatar_node.humanoid_data)

		# Mouth
		var head_global_transform: Transform = Transform()
		if head_id != -1 and avatar_skeleton:
			head_global_transform =\
			node_util_const.get_relative_global_transform(avatar_node, skeleton)\
			* bone_lib_const.get_bone_global_rest_transform(head_id, avatar_skeleton)
		else:
			head_global_transform = Transform(Basis(), Vector3(0.0, 1.0, 0.0) * (default_avatar_height))
		
		var mouth_spatial: Spatial = avatar_node.get_node_or_null(avatar_node.mouth_transform_node_path)
		var mouth_global_transform: Transform
		if mouth_spatial:
			# Get the global transform of the mouth relative to the avatar root
			mouth_global_transform =\
			node_util_const.get_relative_global_transform(avatar_node, skeleton)\
			* mouth_spatial.transform
		else:
			mouth_global_transform = head_global_transform
		
		relative_mouth_transform = head_global_transform.inverse() * mouth_global_transform

		setup_bone_attachments(humanoid_data, avatar_skeleton)

		# Change the world scale to match
		if is_network_master():
			calculate_proportions()
		else:
			pass
		
		_update_voice_player()
		
		emit_signal("avatar_changed")
	else:
		printerr("Avatar %s is not valid!" % get_avatar_model_path())
		load_error_avatar()

func try_head_shrink() -> void:
	if shrink_mode == shrink_enum.SHRINK or \
	(shrink_mode == shrink_enum.DETERMINED_BY_VIEW and _player_camera_controller and _player_camera_controller.camera_mode == player_camera_controller_const.CAMERA_FIRST_PERSON):
		shrink_head()


func shrink_head() -> void:
	if avatar_skeleton and head_id != -1:
		var custom_head_pose: Transform = Transform().scaled(Vector3(0.0, 0.0, 0.0))
		avatar_skeleton.set_bone_custom_pose(head_id, avatar_skeleton.get_bone_custom_pose(head_id) * custom_head_pose)

func save_head() -> void:
	if avatar_skeleton and head_id != -1:
		saved_head_transform = avatar_skeleton.get_bone_custom_pose(head_id)

func restore_head() -> void:
	if avatar_skeleton and head_id != -1:
		avatar_skeleton.set_bone_custom_pose(head_id, saved_head_transform)

func _setup_voice() -> void:
	if ! is_network_master():
		var godot_speech: Node = get_node_or_null("/root/GodotSpeech")
		if godot_speech:
			if ! voice_player:
				voice_player = get_node_or_null(voice_player_path)
				
			godot_speech.voice_controller.add_player_audio(get_network_master(), voice_player)

###

	
func _entity_ready() -> void:
	VRManager.connect("xr_mode_changed", self, "calculate_proportions")
	
	set_as_toplevel(false)
	set_transform(Transform(AVATAR_BASIS, Vector3()))
	
	_setup_voice()

	_player_camera_controller = get_node_or_null(player_camera_controller_path)
	_ik_space = get_node_or_null(_ik_space_path)
	
	_instance_avatar()

func _threaded_instance_setup() -> void:
	create_bone_attachments()
	setup_bone_attachments(null, null)
