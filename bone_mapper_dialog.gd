@tool
extends AcceptDialog

const DIALOG_WIDTH = 600
const DIALOG_HEIGHT = 800

const bone_selection_dialog_const = preload("bone_selection_dialog.gd")
const humanoid_data_const = preload("humanoid_data.gd")
const avatar_constants_const = preload("avatar_constants.gd")

const bone_mapper_button_const = preload("bone_mapper_button.gd")

var body_bone_names: PackedStringArray = PackedStringArray(
	[
		"head_bone_name",
		"neck_bone_name",
		"shoulder_left_bone_name",
		"upper_arm_left_bone_name",
		"forearm_left_bone_name",
		"hand_left_bone_name",
		"shoulder_right_bone_name",
		"upper_arm_right_bone_name",
		"forearm_right_bone_name",
		"hand_right_bone_name",
		"spine_bone_name",
		"chest_bone_name",
		"upper_chest_bone_name",
		"hips_bone_name",
		"thigh_left_bone_name",
		"shin_left_bone_name",
		"foot_left_bone_name",
		"toe_left_bone_name",
		"thigh_right_bone_name",
		"shin_right_bone_name",
		"foot_right_bone_name",
		"toe_right_bone_name",
	]
)

var head_bone_names: PackedStringArray = PackedStringArray(
	["eye_left_bone_name", "eye_right_bone_name", "jaw_bone_name"]
)

var bone_selection_dialog: ConfirmationDialog = null

var left_hand_bone_names: PackedStringArray = PackedStringArray()
var right_hand_bone_names: PackedStringArray = PackedStringArray()

var currently_selected_humanoid_bone: String = ""

var clear_icon: Texture = null
var bone_icon: Texture = null

static func get_hand_name_list(p_side: int) -> PackedStringArray:
	var bone_names: PackedStringArray

	var side_name: String = avatar_constants_const.get_name_for_side(p_side)

	for digit_name in avatar_constants_const.digit_names:
		for digit_joint_name in avatar_constants_const.digit_joint_names:
			bone_names.push_back("%s_%s_%s_bone_name" % [digit_name, digit_joint_name, side_name])

	return bone_names

static func get_bone_unassigned_name() -> String:
	return "unassigned"

var body_bone_buttons: Array = []
var head_bone_buttons: Array = []
var left_hand_bone_buttons: Array = []
var right_hand_bone_buttons: Array = []

var skeleton: Skeleton3D = null
var humanoid_data: HumanoidData = null

var tab_container: TabContainer = null

var body_control: Control = null
var head_control: Control = null
var left_hand_bone_control: Control = null
var right_hand_bone_control: Control = null


func set_humanoid_data(p_humanoid_data: HumanoidData) -> void:
	humanoid_data = p_humanoid_data


func set_skeleton(p_skeleton: Skeleton3D) -> void:
	skeleton = p_skeleton
	bone_selection_dialog.set_skeleton(skeleton)


func _about_to_popup() -> void:
	update_all_buttons()


func button_pressed(p_humanoid_bone_name: String) -> void:
	currently_selected_humanoid_bone = p_humanoid_bone_name
	bone_selection_dialog.popup_centered()
	
func clear_pressed(p_humanoid_bone_name: String) -> void:
	if humanoid_data:
		humanoid_data.set(p_humanoid_bone_name, "")
		update_all_buttons()


func selected(p_bone_name: String) -> void:
	if humanoid_data:
		humanoid_data.set(currently_selected_humanoid_bone, p_bone_name)
		update_all_buttons()


func setup_list(p_tab: Control, p_bones: PackedStringArray, p_button_array: Array) -> void:
	var vbox_container: VBoxContainer = VBoxContainer.new()
	p_tab.add_child(vbox_container)
	vbox_container.set_anchors_and_offsets_preset(VBoxContainer.PRESET_WIDE, Control.PRESET_MODE_MINSIZE, 0)
	vbox_container.size_flags_horizontal = VBoxContainer.SIZE_EXPAND_FILL

	for i in range(0, p_bones.size()):
		var hbox_container: HBoxContainer = HBoxContainer.new()

		var label: Label = Label.new()
		label.set_text(p_bones[i])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var bone_mapper_button = bone_mapper_button_const.new()
		var button_pressed_callable = Callable(self, "button_pressed")
		var clear_pressed_callable = Callable(self, "clear_pressed")
		assert(bone_mapper_button.select_bone_button.connect("pressed", button_pressed_callable.bind(p_bones[i])) == OK)
		assert(bone_mapper_button.clear_bone_button.connect("pressed", clear_pressed_callable.bind(p_bones[i])) == OK)

		p_button_array.push_back(bone_mapper_button)

		hbox_container.add_child(label)
		hbox_container.add_child(bone_mapper_button)

		label.size_flags_horizontal = Label.SIZE_EXPAND_FILL
		bone_mapper_button.size_flags_horizontal = Label.SIZE_EXPAND_FILL

		vbox_container.add_child(hbox_container)


func update_button_group(p_names: PackedStringArray, p_buttons: Array) -> void:
	if p_names.size() != p_buttons.size():
		printerr("Button name size mismatch!")

	for i in range(0, p_buttons.size()):
		var select_button: Button = p_buttons[i].select_bone_button
		var clear_button: Button = p_buttons[i].clear_bone_button
		if select_button:
			select_button.set_button_icon(bone_icon)
			select_button.set_text(get_bone_unassigned_name())
			if humanoid_data:
				var bone_name: String = humanoid_data.get(p_names[i])
				if bone_name != "":
					if skeleton and skeleton.find_bone(bone_name) != -1:
						select_button.set_text(bone_name)
					else:
						select_button.set_text("%s (not found)" % bone_name)
		if clear_button:
			clear_button.set_button_icon(clear_icon)


func update_all_buttons() -> void:
	update_button_group(body_bone_names, body_bone_buttons)
	update_button_group(head_bone_names, head_bone_buttons)
	update_button_group(left_hand_bone_names, left_hand_bone_buttons)
	update_button_group(right_hand_bone_names, right_hand_bone_buttons)


func _ready() -> void:
	if connect("about_to_popup", Callable(self, "_about_to_popup")) & 0xffffffff != OK:
		printerr("Could not connect to about_to_popup")

	if bone_selection_dialog.connect("selected", Callable(self, "selected")) & 0xffffffff != OK:
		printerr("Could not connect signal!")


func _init(p_bone_icon: Texture, p_clear_icon: Texture):
	set_title("Assign bones")
	set_size(Vector2(DIALOG_WIDTH, DIALOG_HEIGHT))

	unresizable = false

	bone_icon = p_bone_icon
	clear_icon = p_clear_icon

	bone_selection_dialog = bone_selection_dialog_const.new(bone_icon, clear_icon)
	add_child(bone_selection_dialog)

	left_hand_bone_names = get_hand_name_list(avatar_constants_const.SIDE_LEFT)
	right_hand_bone_names = get_hand_name_list(avatar_constants_const.SIDE_RIGHT)

	tab_container = TabContainer.new()

	body_control = ScrollContainer.new()
	body_control.scroll_horizontal = false
	head_control = ScrollContainer.new()
	head_control.scroll_horizontal = false
	left_hand_bone_control = ScrollContainer.new()
	left_hand_bone_control.scroll_horizontal = false
	right_hand_bone_control = ScrollContainer.new()
	right_hand_bone_control.scroll_horizontal = false
	
	body_control.set_name("Body")
	head_control.set_name("Head")
	left_hand_bone_control.set_name("Left Hand")
	right_hand_bone_control.set_name("Right Hand")

	add_child(tab_container)

	tab_container.add_child(body_control)
	tab_container.add_child(head_control)
	tab_container.add_child(left_hand_bone_control)
	tab_container.add_child(right_hand_bone_control)

	tab_container.set_anchors_and_offsets_preset(Control.PRESET_WIDE, Control.PRESET_MODE_MINSIZE, 0)
	body_control.set_anchors_and_offsets_preset(Control.PRESET_WIDE, Control.PRESET_MODE_MINSIZE, 0)
	head_control.set_anchors_and_offsets_preset(Control.PRESET_WIDE, Control.PRESET_MODE_MINSIZE, 0)
	left_hand_bone_control.set_anchors_and_offsets_preset(
		Control.PRESET_WIDE, Control.PRESET_MODE_MINSIZE, 0
	)
	right_hand_bone_control.set_anchors_and_offsets_preset(
		Control.PRESET_WIDE, Control.PRESET_MODE_MINSIZE, 0
	)
	
	tab_container.use_hidden_tabs_for_min_size = true
	min_size = tab_container.get_minimum_size()

	setup_list(body_control, body_bone_names, body_bone_buttons)
	setup_list(head_control, head_bone_names, head_bone_buttons)
	setup_list(left_hand_bone_control, left_hand_bone_names, left_hand_bone_buttons)
	setup_list(right_hand_bone_control, right_hand_bone_names, right_hand_bone_buttons)
