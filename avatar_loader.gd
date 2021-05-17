extends Node

signal avatar_changed
signal avatar_download_started(p_url)
signal avatar_load_stage(p_stage, p_stage_count)
signal avatar_cleared
signal avatar_ready(packed_scene)

var avatar_packed_scene: PackedScene = null
var avatar_path: String = ""
var avatar_pending: bool = false

func _instance_avatar() -> void:
	if is_inside_tree():
		if avatar_packed_scene:
			emit_signal("avatar_ready", avatar_packed_scene)
			avatar_packed_scene = null

func _avatar_load_finished() -> void:
	VSKAvatarManager.disconnect("avatar_download_started", self, "_avatar_download_started")
	VSKAvatarManager.disconnect("avatar_load_callback", self, "_avatar_load_callback")
	VSKAvatarManager.disconnect("avatar_load_update", self, "_avatar_load_update")

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
			emit_signal("avatar_cleared")
			printerr("Could not load failed avatar!")

func _avatar_download_started(p_url: String) -> void:
	if avatar_pending and p_url == avatar_path:
		emit_signal("avatar_download_started", p_url)

func _avatar_load_callback(p_url: String, p_err: int, p_packed_scene: PackedScene) -> void:
	if p_err == VSKAssetManager.ASSET_OK:
		_avatar_load_succeeded(p_url, p_packed_scene)
	else:
		_avatar_load_failed(p_url, p_err)

func _avatar_load_update(p_url: String, p_stage: int, p_stage_count: int) -> void:
	if avatar_pending and p_url == avatar_path:
		emit_signal("avatar_load_stage", p_stage, p_stage_count)

func get_avatar_model_path() -> String:
	return avatar_path

func set_avatar_model_path(p_path: String) -> void:
	if avatar_path != p_path:
		if avatar_path != "":
			VSKAvatarManager.cancel_avatar(avatar_path)

		avatar_path = p_path

func load_model(p_bypass_whitelist: bool) -> void:
	if ! avatar_pending:
		assert(VSKAvatarManager.connect("avatar_download_started", self, "_avatar_download_started") == OK)
		assert(VSKAvatarManager.connect("avatar_load_callback", self, "_avatar_load_callback") == OK)
		assert(VSKAvatarManager.connect("avatar_load_update", self, "_avatar_load_update") == OK)
		
		avatar_pending = true
	VSKAvatarManager.call_deferred("request_avatar", avatar_path, p_bypass_whitelist)

func load_error_avatar() -> void:
	emit_signal("avatar_cleared")
	set_avatar_model_path(VSKAssetManager.avatar_error_path)
	load_model(true)

func _on_avatar_setup_complete():
	emit_signal("avatar_changed")
	
func _on_avatar_setup_failed():
	printerr("Avatar %s is not valid!" % get_avatar_model_path())
	load_error_avatar()
