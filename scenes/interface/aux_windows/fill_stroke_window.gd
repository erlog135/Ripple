extends Control

const COLOR_POPUP = preload("uid://opfiwgeouvns")
@onready var fill_rect: ColorRect = $Panel/Options/FillColor/ColorRect
@onready var stroke_rect: ColorRect = $Panel/Options/StrokeColor/ColorRect
@onready var stroke_width_spin: SpinBox = $Panel/Options/StrokeWidth/SpinBox

var fill_popup: PopupPanel
var stroke_popup: PopupPanel

var _syncing := false

func _ready() -> void:
	fill_popup = COLOR_POPUP.instantiate()
	fill_rect.add_child(fill_popup)
	fill_popup.color_selected.connect(_on_fill_color_selected)
	fill_rect.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			fill_popup.popup_centered())

	stroke_popup = COLOR_POPUP.instantiate()
	stroke_rect.add_child(stroke_popup)
	stroke_popup.color_selected.connect(_on_stroke_color_selected)
	stroke_rect.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			stroke_popup.popup_centered())

	stroke_width_spin.value_changed.connect(_on_stroke_width_changed)
	EditorState.selection_changed.connect(_on_selection_changed)


func _on_fill_color_selected(color: Color) -> void:
	fill_rect.color = color
	if _syncing:
		return
	_commit_property_change(&"fill_color", color, "Set Fill Color")


func _on_stroke_color_selected(color: Color) -> void:
	stroke_rect.color = color
	if _syncing:
		return
	_commit_property_change(&"stroke_color", color, "Set Stroke Color")


func _on_stroke_width_changed(value: float) -> void:
	if _syncing:
		return
	_commit_property_change(&"stroke_width", int(value), "Set Stroke Width", UndoRedo.MERGE_ENDS)


func _commit_property_change(property: StringName, new_value: Variant, action_name: String, merge_mode := UndoRedo.MERGE_DISABLE) -> void:
	var indices := EditorState.selected_command_indices
	if indices.is_empty() or not ProjectData.current_sequence:
		return
	var frame: DrawCommandImage = ProjectData.current_sequence.frames[EditorState.current_frame]
	var ur := HistoryManager.undo_redo
	ur.create_action(action_name, merge_mode)
	for idx in indices:
		var cmd: DrawCommand = frame.commands[idx]
		ur.add_undo_property(cmd, property, cmd.get(property))
		ur.add_do_property(cmd, property, new_value)
	ur.add_do_method(func(): ProjectData.data_changed.emit(false))
	ur.add_undo_method(func(): ProjectData.data_changed.emit(false))
	ur.commit_action()


func _on_selection_changed(_by_user: bool) -> void:
	var indices: Array[int] = EditorState.selected_command_indices
	if indices.is_empty() or not ProjectData.current_sequence:
		return

	var frame: DrawCommandImage = ProjectData.current_sequence.frames[EditorState.current_frame]
	var first: DrawCommand = frame.commands[indices[0]]
	var shared_fill := first.fill_color
	var shared_stroke := first.stroke_color
	var shared_width := first.stroke_width

	for i in range(1, indices.size()):
		var cmd: DrawCommand = frame.commands[indices[i]]
		if cmd.fill_color != shared_fill or cmd.stroke_color != shared_stroke or cmd.stroke_width != shared_width:
			return

	_syncing = true
	fill_popup.select_color(shared_fill)
	stroke_popup.select_color(shared_stroke)
	stroke_width_spin.value = shared_width
	_syncing = false
