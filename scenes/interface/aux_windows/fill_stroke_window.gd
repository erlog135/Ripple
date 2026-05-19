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


func _sync_current_from_editor_ui() -> void:
	EditorState.set_current_fill_stroke(
		fill_rect.color,
		stroke_rect.color,
		int(stroke_width_spin.value),
	)


func _on_fill_color_selected(color: Color) -> void:
	fill_rect.color = color
	EditorState.set_current_fill_color(color)
	if _syncing:
		return
	var indices := EditorState.selected_command_indices
	if indices.is_empty() or ProjectData.get_current_image() == null:
		return
	HistoryManager.commit(SetFillColorAction.new(EditorState.current_frame, indices, color))


func _on_stroke_color_selected(color: Color) -> void:
	stroke_rect.color = color
	EditorState.set_current_stroke_color(color)
	if _syncing:
		return
	var indices := EditorState.selected_command_indices
	if indices.is_empty() or ProjectData.get_current_image() == null:
		return
	HistoryManager.commit(SetStrokeColorAction.new(EditorState.current_frame, indices, color))


func _on_stroke_width_changed(value: float) -> void:
	EditorState.set_current_stroke_width(int(value))
	if _syncing:
		return
	var indices := EditorState.selected_command_indices
	if indices.is_empty() or ProjectData.get_current_image() == null:
		return
	HistoryManager.commit(
		SetStrokeWidthAction.new(EditorState.current_frame, indices, int(value)),
		UndoRedo.MERGE_ENDS,
	)



func _on_selection_changed(_by_user: bool) -> void:
	var indices: Array[int] = EditorState.selected_command_indices
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if indices.is_empty() or frame == null:
		return

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
	EditorState.set_current_fill_stroke(shared_fill, shared_stroke, shared_width)
	_syncing = false
