extends Spatial

signal external_trackers_changed

const bone_lib_const = preload("res://addons/vsk_avatar/bone_lib.gd")

export(NodePath) var _player_input_path : NodePath = NodePath()
var _player_input_node : Node = null

export(bool) var pin_at_world_origin = false
export(bool) var debug_points = false
export(float) var origin_interpolation_factor : float = 0.0
export(float) var rotation_interpolation_factor : float = 0.0

export(NodePath) var _camera_controller_node_path : NodePath = NodePath()
export(NodePath) var _ren_ik_path : NodePath = NodePath()
export(NodePath) var _avatar_display_path : NodePath = NodePath()

const IK_POINT_HEAD_BASIS_GLOBAL = Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, -1.0))
const IK_POINT_LEFT_HAND_BASIS_GLOBAL = Basis(Vector3(0.0, -0.707, 0.707), Vector3(0.0, -0.707, -0.707), Vector3(1.0, 0.0, 0.0))
const IK_POINT_RIGHT_HAND_BASIS_GLOBAL = Basis(Vector3(0.0, 0.707, -0.707), Vector3(0.0, -0.707, -0.707), Vector3(-1.0, 0.0, 0.0))

const IK_HAND_OFFSET = Vector3(0.01, 0.014, 0.13) # Right hand

enum ik_points {
	HEAD_ID = 0,
	LEFT_HAND_ID,
	RIGHT_HAND_ID,
	LEFT_FOOT_ID,
	RIGHT_FOOT_ID,
	HIPS_ID,
	CHEST_ID
}

const MOCAP_RECORDING_ENABLED: bool = false

const HEAD_BIT = (1 << ik_points.HEAD_ID)
const LEFT_HAND_BIT = (1 << ik_points.LEFT_HAND_ID)
const RIGHT_HAND_BIT = (1 << ik_points.RIGHT_HAND_ID)
const LEFT_FOOT_BIT = (1 << ik_points.LEFT_FOOT_ID)
const RIGHT_FOOT_BIT = (1 << ik_points.RIGHT_FOOT_ID)
const HIPS_BIT = (1 << ik_points.HIPS_ID)
const CHEST_BIT = (1 << ik_points.CHEST_ID)

var previous_external_mask : int = 0
var current_external_mask : int = 0

var _avatar_display_node : Node = null
var _camera_controller_node : Node = null
var _ren_ik : Node = null

var target_transforms : Array = []

var mocap_recording: Reference = null

class TrackerCollection extends Reference:
	var head_spatial : Spatial = null
	var left_hand_spatial : Spatial = null
	var right_hand_spatial : Spatial = null
	var left_foot_spatial : Spatial = null
	var right_foot_spatial : Spatial = null
	var hips_spatial : Spatial = null
	var chest_spatial : Spatial = null
	
	func clear() -> void:
		if head_spatial:
			head_spatial.queue_free()
			head_spatial = null
		if left_hand_spatial:
			left_hand_spatial.queue_free()
			left_hand_spatial = null
		if right_hand_spatial:
			right_hand_spatial.queue_free()
			right_hand_spatial = null
		if left_foot_spatial:
			left_foot_spatial.queue_free()
			left_foot_spatial = null
		if hips_spatial:
			hips_spatial.queue_free()
			hips_spatial = null
		if chest_spatial:
			chest_spatial.queue_free()
			chest_spatial = null
	
var tracker_collection_input : TrackerCollection = null
var tracker_collection_output : TrackerCollection = null

# Local transform cache
var rest_local_transforms : Array = []
var pose_local_transforms : Array = []
var custom_local_transforms : Array = []

var output_trackers_is_dirty: bool = true

func resize_local_transform_cache(p_size) -> void:
	rest_local_transforms.resize(p_size)
	pose_local_transforms.resize(p_size)
	custom_local_transforms.resize(p_size)

var eye_offset : Vector3 = Vector3()
var mouth_offset : Vector3 = Vector3()

const gizmo_reference_const = preload("res://addons/vsk_avatar/gizmo_reference.tscn")
			
func _create_output_trackers() -> void:
	if ! tracker_collection_output:
		tracker_collection_output = TrackerCollection.new()
		
		tracker_collection_output.head_spatial = create_new_spatial_point("HeadOutput", Transform(), true)
		tracker_collection_output.hips_spatial = create_new_spatial_point("HipsOutput", Transform(), true)
		tracker_collection_output.left_hand_spatial = create_new_spatial_point("LeftHandOutput", Transform(), true)
		tracker_collection_output.right_hand_spatial = create_new_spatial_point("RightHandOutput", Transform(), true)
		tracker_collection_output.left_foot_spatial = create_new_spatial_point("LeftFootOutput", Transform(), true)
		tracker_collection_output.right_foot_spatial = create_new_spatial_point("RightFootOutput", Transform(), true)
				
func _external_trackers_updated():
	if NetworkManager.is_server():
		_create_output_trackers()
				
func update_trackers() -> void:
	if is_network_master():
		if VRManager.is_xr_active():
			tracker_collection_input.head_spatial = create_new_spatial_point("HeadInput", Transform(Basis(), Vector3()), false)
			
			if VRManager.xr_origin.left_hand_controller:
				tracker_collection_input.left_hand_spatial = create_new_spatial_point("LeftHandInput", Transform(Basis(), Vector3()), false)
				
			if VRManager.xr_origin.right_hand_controller:
				tracker_collection_input.right_hand_spatial = create_new_spatial_point("RightHandInput", Transform(Basis(), Vector3()), false)
				
			if VRManager.xr_origin.connect("tracker_added", self, "_on_tracker_added") != OK:
				printerr("Could not connect tracker_added!")
			if VRManager.xr_origin.connect("tracker_removed", self, "_on_tracker_removed") != OK:
				printerr("Could not connect tracker_removed!")
			
			update_local_transforms()
			# Connect to the IK system
		else:
			if VRManager.xr_origin.is_connected("tracker_added", self, "_on_tracker_added"):
				VRManager.xr_origin.disconnect("tracker_added", self, "_on_tracker_added")
			if VRManager.xr_origin.is_connected("tracker_removed", self, "_on_tracker_removed"):
				VRManager.xr_origin.disconnect("tracker_removed", self, "_on_tracker_removed")
			tracker_collection_input.head_spatial = create_new_spatial_point("HeadInput", Transform(Basis(), Vector3()), false)
				
func update_ik_controller() -> void:
	# This causes a memory a leak! Static memory is allocated and never released!
	if _ren_ik:
		if tracker_collection_input:
			if tracker_collection_input.head_spatial:
				_ren_ik.set_head_target_path(_ren_ik.get_path_to(tracker_collection_input.head_spatial))
			if tracker_collection_input.left_hand_spatial:
				_ren_ik.set_hand_left_target_path(_ren_ik.get_path_to(tracker_collection_input.left_hand_spatial))
			if tracker_collection_input.right_hand_spatial:
				_ren_ik.set_hand_right_target_path(_ren_ik.get_path_to(tracker_collection_input.right_hand_spatial))
			if tracker_collection_input.hips_spatial:
				_ren_ik.set_hip_target_path(_ren_ik.get_path_to(tracker_collection_input.hips_spatial.get_node_or_null("Rotation")))
			if tracker_collection_input.left_foot_spatial:
				_ren_ik.set_foot_left_target_path(_ren_ik.get_path_to(tracker_collection_input.left_foot_spatial.get_node_or_null("Rotation")))
			if tracker_collection_input.right_foot_spatial:
				_ren_ik.set_foot_right_target_path(_ren_ik.get_path_to(tracker_collection_input.right_foot_spatial.get_node_or_null("Rotation")))

func create_new_spatial_point(p_name : String, p_transform : Transform, p_no_debug : bool = false) -> Spatial:
	var spatial : Spatial = Spatial.new()
	spatial.set_name(p_name)
	
	var spatial_rotation : Spatial = Spatial.new()
	spatial_rotation.set_name("Rotation")
	spatial.add_child(spatial_rotation)
	spatial_rotation.set_transform(p_transform)
	
	if !p_no_debug and debug_points:
		var gizmo_reference : Spatial = gizmo_reference_const.instance()
		spatial_rotation.add_child(gizmo_reference)
	
	add_child(spatial)
	return spatial

func _on_tracker_added(p_tracker : Spatial) -> void:
	var arvr_controller : ARVRController = p_tracker
	
	if arvr_controller:
		var should_update_ik_controller : bool = false
		print("Tracker added to IK space: %s" % p_tracker.get_name())
		
		var hand : int = arvr_controller.get_hand()
		match hand:
			ARVRPositionalTracker.TRACKER_LEFT_HAND:
				if VRManager.xr_origin.left_hand_controller:
					if tracker_collection_input.left_hand_spatial == null:
						tracker_collection_input.left_hand_spatial = create_new_spatial_point("LeftHandInput", Transform(Basis(), Vector3()), false)
						should_update_ik_controller = true
			ARVRPositionalTracker.TRACKER_RIGHT_HAND:
				if VRManager.xr_origin.right_hand_controller:
					if tracker_collection_input.right_hand_spatial == null:
						tracker_collection_input.right_hand_spatial = create_new_spatial_point("RightHandInput", Transform(Basis(), Vector3()), false)
						should_update_ik_controller = true
		
		if should_update_ik_controller:
			update_ik_controller()

func _on_tracker_removed(p_tracker : Spatial) -> void:
	var arvr_controller : ARVRController = p_tracker
	
	if arvr_controller:
		var should_update_ik_controller : bool = false
		print("Tracker removed from IK space: %s" % p_tracker.get_name())
		
		var hand : int = arvr_controller.get_hand()
		match hand:
			ARVRPositionalTracker.TRACKER_LEFT_HAND:
				if VRManager.xr_origin.left_hand_controller == null:
					if tracker_collection_input.left_hand_spatial:
						tracker_collection_input.left_hand_spatial.queue_free()
						tracker_collection_input.left_hand_spatial.get_parent().remove_child(tracker_collection_input.left_hand_spatial)
						tracker_collection_input.left_hand_spatial = null
						should_update_ik_controller = true
			ARVRPositionalTracker.TRACKER_RIGHT_HAND:
				if VRManager.xr_origin.right_hand_controller == null:
					if tracker_collection_input.right_hand_controller:
						tracker_collection_input.right_hand_controller.queue_free()
						tracker_collection_input.right_hand_controller.get_parent().remove_child(tracker_collection_input.right_hand_controller)
						tracker_collection_input.right_hand_controller = null
						should_update_ik_controller = true
		
		if should_update_ik_controller:
			update_ik_controller()

func update_external_transform(p_mask : int, p_transform_array : Array) -> void:
	if is_inside_tree() and !is_network_master() and tracker_collection_input:
		if current_external_mask != p_mask:
			emit_signal("external_trackers_changed")
		
		current_external_mask = p_mask
		for i in range(0, ik_points.size()):
			if current_external_mask & (1 << i):
				var spatial : Spatial = null
				match i:
					ik_points.HEAD_ID:
						spatial = tracker_collection_input.head_spatial
					ik_points.LEFT_HAND_ID:
						spatial = tracker_collection_input.left_hand_spatial
					ik_points.RIGHT_HAND_ID:
						spatial = tracker_collection_input.right_hand_spatial
					ik_points.LEFT_FOOT_ID:
						spatial = tracker_collection_input.left_foot_spatial
					ik_points.RIGHT_FOOT_ID:
						spatial = tracker_collection_input.right_foot_spatial
					ik_points.HIPS_ID:
						spatial = tracker_collection_input.hips_spatial
					ik_points.CHEST_ID:
						spatial = tracker_collection_input.chest_spatial
						
				if spatial == null:
					var spatial_name : String = ""
					match i:
						ik_points.HEAD_ID:
							spatial_name = "HeadInput"
							spatial = create_new_spatial_point(spatial_name, Transform(Basis(), Vector3()))
							tracker_collection_input.head_spatial = spatial
						ik_points.LEFT_HAND_ID:
							spatial_name = "LeftHandInput"
							spatial = create_new_spatial_point(spatial_name, Transform(Basis(), Vector3()))
							tracker_collection_input.left_hand_spatial = spatial
						ik_points.RIGHT_HAND_ID:
							spatial_name = "RightHandInput"
							spatial = create_new_spatial_point(spatial_name, Transform(Basis(), Vector3()))
							tracker_collection_input.right_hand_spatial = spatial
						ik_points.LEFT_FOOT_ID:
							spatial_name = "LeftFootInput"
							spatial = create_new_spatial_point(spatial_name, Transform(Basis(), Vector3()))
							tracker_collection_input.left_foot_spatial = spatial
						ik_points.RIGHT_FOOT_ID:
							spatial_name = "RightFootInput"
							spatial = create_new_spatial_point(spatial_name, Transform(Basis(), Vector3()))
							tracker_collection_input.right_foot_spatial = spatial
						ik_points.HIPS_ID:
							spatial_name = "HipsInput"
							spatial = create_new_spatial_point(spatial_name, Transform(Basis(), Vector3()))
							tracker_collection_input.hips_spatial = spatial
						ik_points.CHEST_ID:
							spatial_name = "ChestInput"
							spatial = create_new_spatial_point(spatial_name, Transform(Basis(), Vector3()))
							tracker_collection_input.chest_spatial = spatial
					spatial.set_transform(p_transform_array[i])
				target_transforms[i] = p_transform_array[i]
			else:
				match i:
					ik_points.HEAD_ID:
						if tracker_collection_input.head_spatial != null:
							tracker_collection_input.head_spatial.queue_free()
							tracker_collection_input.head_spatial = null
					ik_points.LEFT_HAND_ID:
						if tracker_collection_input.left_hand_spatial != null:
							tracker_collection_input.left_hand_spatial.queue_free()
							tracker_collection_input.left_hand_spatial = null
					ik_points.RIGHT_HAND_ID:
						if tracker_collection_input.right_hand_spatial != null:
							tracker_collection_input.right_hand_spatial.queue_free()
							tracker_collection_input.right_hand_spatial = null
					ik_points.LEFT_FOOT_ID:
						if tracker_collection_input.left_foot_spatial != null:
							tracker_collection_input.left_foot_spatial.queue_free()
							tracker_collection_input.left_foot_spatial = null
					ik_points.RIGHT_FOOT_ID:
						if tracker_collection_input.right_foot_spatial != null:
							tracker_collection_input.right_foot_spatial.queue_free()
							tracker_collection_input.right_foot_spatial = null
					ik_points.HIPS_ID:
						if tracker_collection_input.hips_spatial != null:
							tracker_collection_input.hips_spatial.queue_free()
							tracker_collection_input.hips_spatial = null
					ik_points.CHEST_ID:
						if tracker_collection_input.chest_spatial != null:
							tracker_collection_input.chest_spatial.queue_free()
							tracker_collection_input.chest_spatial = null
							
	
func interpolate_transforms(p_delta : float) -> void:
	if current_external_mask != previous_external_mask:
		update_ik_controller()
		previous_external_mask = current_external_mask
	
	if tracker_collection_input:
		# Head
		if tracker_collection_input.head_spatial:
			tracker_collection_input.head_spatial.transform = GodotMathExtension.get_interpolated_transform(tracker_collection_input.head_spatial.transform, target_transforms[ik_points.HEAD_ID], origin_interpolation_factor, rotation_interpolation_factor, p_delta)
		# Hands
		if tracker_collection_input.left_hand_spatial:
			tracker_collection_input.left_hand_spatial.transform = GodotMathExtension.get_interpolated_transform(tracker_collection_input.left_hand_spatial.transform, target_transforms[ik_points.LEFT_HAND_ID], origin_interpolation_factor, rotation_interpolation_factor, p_delta)
		if tracker_collection_input.right_hand_spatial:
			tracker_collection_input.right_hand_spatial.transform = GodotMathExtension.get_interpolated_transform(tracker_collection_input.right_hand_spatial.transform, target_transforms[ik_points.RIGHT_HAND_ID], origin_interpolation_factor, rotation_interpolation_factor, p_delta)
		# Feet
		if tracker_collection_input.left_foot_spatial:
			tracker_collection_input.left_foot_spatial.transform = GodotMathExtension.get_interpolated_transform(tracker_collection_input.left_foot_spatial.transform, target_transforms[ik_points.LEFT_FOOT_ID], origin_interpolation_factor, rotation_interpolation_factor, p_delta)
		if tracker_collection_input.right_foot_spatial:
			tracker_collection_input.right_foot_spatial.transform = GodotMathExtension.get_interpolated_transform(tracker_collection_input.right_foot_spatial.transform, target_transforms[ik_points.RIGHT_FOOT_ID], origin_interpolation_factor, rotation_interpolation_factor, p_delta)
		# Torso
		if tracker_collection_input.hips_spatial:
			tracker_collection_input.hips_spatial.transform = GodotMathExtension.get_interpolated_transform(tracker_collection_input.hips_spatial.transform, target_transforms[ik_points.HIPS_ID], origin_interpolation_factor, rotation_interpolation_factor, p_delta)
		if tracker_collection_input.chest_spatial:
			tracker_collection_input.chest_spatial.transform = GodotMathExtension.get_interpolated_transform(tracker_collection_input.chest_spatial.transform, target_transforms[ik_points.CHEST_ID], origin_interpolation_factor, rotation_interpolation_factor, p_delta)
				
func get_local_head_transform(p_camera: Spatial, p_origin_offset: Vector3, p_camera_offset: Vector3) -> Transform:
	var tilt_ratio: float = 0.0
	var offset_value: float = 1.0
	# If we're not in VR, modify the offset of the head based on pitch
	if ! VRManager.is_xr_active():
		offset_value = p_camera.transform.basis.get_euler().x / (PI * 0.5)
		tilt_ratio = abs(offset_value)
	
	var relative_offset : Vector3 = Vector3(\
	0.0,\
	lerp(-eye_offset.y, eye_offset.z * sign(offset_value) * 2.0, tilt_ratio),\
	lerp(eye_offset.z, eye_offset.y * sign(offset_value) * 2.0, tilt_ratio))
	
	return Transform().rotated(\
	Vector3.UP, PI) * Transform(p_camera.transform.basis,\
	(p_camera.transform.origin + p_origin_offset - p_camera_offset)).translated(\
	relative_offset) * Transform(IK_POINT_HEAD_BASIS_GLOBAL)
				
func update_local_transforms() -> void:
	var camera_offset : Vector3 = _player_input_node.get_head_accumulator()
	var origin_offset : Vector3 = -_camera_controller_node.origin_offset

	if tracker_collection_input:
		if tracker_collection_input.head_spatial:
			var camera : ARVRCamera = VRManager.xr_origin.get_node_or_null("ARVRCamera")
			tracker_collection_input.head_spatial.transform = \
			get_local_head_transform(camera, origin_offset, camera_offset)
		
		if tracker_collection_input.left_hand_spatial:
			var controller : ARVRController = VRManager.xr_origin.left_hand_controller
			if controller:
				tracker_collection_input.left_hand_spatial.transform = Transform().rotated(Vector3(0.0, 1.0, 0.0), PI) * Transform(controller.transform.basis, (controller.transform.origin + origin_offset - camera_offset)).translated(Vector3(-IK_HAND_OFFSET.x, IK_HAND_OFFSET.y, IK_HAND_OFFSET.z)) * Transform(IK_POINT_LEFT_HAND_BASIS_GLOBAL)
		if tracker_collection_input.right_hand_spatial:
			var controller : ARVRController = VRManager.xr_origin.right_hand_controller
			if controller:
				tracker_collection_input.right_hand_spatial.transform = Transform().rotated(Vector3(0.0, 1.0, 0.0), PI) * Transform(controller.transform.basis, (controller.transform.origin + origin_offset - camera_offset)).translated(Vector3(IK_HAND_OFFSET.x, IK_HAND_OFFSET.y, IK_HAND_OFFSET.z)) * Transform(IK_POINT_RIGHT_HAND_BASIS_GLOBAL)
			
# Calculate the transforms of the trackers to be serialised by the network writer
func update_output_trackers() -> void:
	if tracker_collection_output and _avatar_display_node:
		var skeleton : Skeleton = _avatar_display_node.avatar_skeleton
		if skeleton:
			# Calculate the transforms for the output trackers based on the global poses
			var head_transform : Transform = skeleton.get_bone_global_pose(_avatar_display_node.head_id) # bone_lib_const.get_bone_global_transform(_avatar_display_node.head_id, skeleton, local_transforms_array)
			if is_network_master():
				head_transform = Transform(head_transform.basis.orthonormalized().scaled(_avatar_display_node.saved_head_transform.basis.get_scale()), head_transform.origin);
			
			# The outgoing hips rotation should treat the default rotation as identity,
			# so apply the inverse of the rest pose to actual global pose here
			
			# TODO: we may want to use global rest as the inverse, but it should probably be cached
			var hips_transform : Transform = skeleton.get_bone_global_pose(_avatar_display_node.hip_id) * Transform(skeleton.get_bone_rest(_avatar_display_node.hip_id).basis.inverse(), Vector3()) # bone_lib_const.get_bone_global_transform(_avatar_display_node.hip_id, skeleton, local_transforms_array)
			
			var left_hand_transform : Transform = skeleton.get_bone_global_pose(_avatar_display_node.left_hand_id) * Transform(skeleton.get_bone_rest(_avatar_display_node.left_hand_id).basis.inverse(), Vector3()) # bone_lib_const.get_bone_global_transform(_avatar_display_node.left_hand_id, skeleton, local_transforms_array)
			var right_hand_transform : Transform = skeleton.get_bone_global_pose(_avatar_display_node.right_hand_id) * Transform(skeleton.get_bone_rest(_avatar_display_node.right_hand_id).basis.inverse(), Vector3()) # bone_lib_const.get_bone_global_transform(_avatar_display_node.right_hand_id, skeleton, local_transforms_array)
			
			var left_foot_transform : Transform = skeleton.get_bone_global_pose(_avatar_display_node.left_foot_id) * Transform(skeleton.get_bone_rest(_avatar_display_node.left_foot_id).basis.inverse(), Vector3()) # bone_lib_const.get_bone_global_transform(_avatar_display_node.left_foot_id, skeleton, local_transforms_array)
			var right_foot_transform : Transform = skeleton.get_bone_global_pose(_avatar_display_node.right_foot_id) * Transform(skeleton.get_bone_rest(_avatar_display_node.right_foot_id).basis.inverse(), Vector3()) # bone_lib_const.get_bone_global_transform(_avatar_display_node.right_foot_id, skeleton, local_transforms_array)
			
			# Global transform is inefficent. Try to find a cheaper way of doing this.
			var affine_inverse: Transform = global_transform.affine_inverse()
			
			# Update the trackers
			tracker_collection_output.head_spatial.transform = affine_inverse * head_transform
			tracker_collection_output.hips_spatial.transform = affine_inverse * hips_transform
			tracker_collection_output.left_hand_spatial.transform = affine_inverse * left_hand_transform
			tracker_collection_output.right_hand_spatial.transform = affine_inverse * right_hand_transform
			tracker_collection_output.left_foot_spatial.transform = affine_inverse * left_foot_transform
			tracker_collection_output.right_foot_spatial.transform = affine_inverse * right_foot_transform
			
	output_trackers_is_dirty = false
	
static func _get_transforms_from_tracker_collection(p_tracker: Reference) -> Array:
	var head_transform: Transform = Transform()
	var left_hand_transform: Transform = Transform()
	var right_hand_transform: Transform = Transform()
	var left_foot_transform: Transform = Transform()
	var right_foot_transform: Transform = Transform()
	var hips_transform: Transform = Transform()
	
	if p_tracker:
		if p_tracker.head_spatial:
			head_transform = p_tracker.head_spatial.transform
			
		if p_tracker.left_hand_spatial:
			left_hand_transform = p_tracker.left_hand_spatial.transform
		
		if p_tracker.right_hand_spatial:
			right_hand_transform = p_tracker.right_hand_spatial.transform
		
		if p_tracker.left_foot_spatial:
			left_foot_transform = p_tracker.left_foot_spatial.transform
		
		if p_tracker.right_foot_spatial:
			right_foot_transform = p_tracker.right_foot_spatial.transform
		
		if p_tracker.hips_spatial:
			hips_transform = p_tracker.hips_spatial.transform
		
	return [head_transform, left_hand_transform, right_hand_transform, left_foot_transform, right_foot_transform, hips_transform]
		
# Called once the IK for this armature has been calculated
func ik_complete() -> void:
	if is_network_master() or NetworkManager.is_server():
		output_trackers_is_dirty = true
		
		if is_network_master():
			_avatar_display_node.save_head()
			_avatar_display_node.try_head_shrink()
			
func execute_ik() -> void:
	if is_network_master():
		_avatar_display_node.restore_head()
	
	if _ren_ik and _avatar_display_node.avatar_node:
		_ren_ik.update_ik()
	
	ik_complete()
	
func transform_update(p_delta) -> void:
	if is_inside_tree():
		if is_network_master():
			update_local_transforms()
		else:
			interpolate_transforms(p_delta)
			
		execute_ik()

# Current assumes physics to be running at 60hz, will behave differently
# at a different physics update rate
func update_physics(p_delta) -> void:
	if is_inside_tree():
		if is_network_master():
			_ren_ik.update_placement(p_delta)
			if mocap_recording:
				update_output_trackers()
				var transform_array = [global_transform] + _get_transforms_from_tracker_collection(tracker_collection_output)
				mocap_recording.write_transform_array(transform_array)
			
			
func setup() -> void:
	if is_inside_tree():
		_player_input_node = get_node_or_null(_player_input_path)
		_avatar_display_node = get_node_or_null(_avatar_display_path)
		_camera_controller_node = get_node_or_null(_camera_controller_node_path)
		_ren_ik = get_node_or_null(_ren_ik_path)
		
		# Check if humanIK script is assigned and instanceable
#		if _ren_ik.get_script() == null or !_ren_ik.get_script().can_instance():
#			printerr("RenIK could not be loaded!")
#			_ren_ik = null
		
		if _ren_ik:
			_ren_ik.set_process(false)
			_ren_ik.set_process_internal(false)
			_ren_ik.set_physics_process(false)
			_ren_ik.set_physics_process_internal(false)
			_ren_ik.enable_hip_placement(true)
			_ren_ik.enable_foot_placement(true)
		
		set_as_toplevel(pin_at_world_origin)
		set_transform(Transform())
		
		tracker_collection_input = TrackerCollection.new()
		
		if is_network_master():
			_create_output_trackers()
			
			if !Engine.is_editor_hint():
				assert(VRManager.connect("xr_mode_changed", self, "update_trackers") == OK)
			
			update_trackers()
			update_ik_controller()
			
			if MocapManager.recording_enabled:
				mocap_recording = MocapManager.start_recording(Engine.iterations_per_second)
	else:
		pass
		
func _on_AvatarDisplay_avatar_changed():
	if (is_network_master() or NetworkManager.is_server()) and\
	_avatar_display_node and\
	_avatar_display_node.avatar_skeleton:
		resize_local_transform_cache(_avatar_display_node.avatar_skeleton.get_bone_count())
	else:
		resize_local_transform_cache(0)


func _entity_ready():
	setup()
	
	var ik_point_count : int = ik_points.size()
	while(ik_point_count > 0):
		target_transforms.push_back(Transform())
		ik_point_count -= 1
	
	if !Engine.is_editor_hint():
		assert(connect("external_trackers_changed", self, "_external_trackers_updated", [], CONNECT_ONESHOT) == OK)
