extends Control

const COLOR_POPUP_SCENE := "res://scenes/interface/popups/ColorPopup.tscn"
@onready var fill_rect: ColorRect = $Panel/MarginContainer/Options/FillColor/ColorRect
@onready var stroke_rect: ColorRect = $Panel/MarginContainer/Options/StrokeColor/ColorRect
@onready var stroke_width_spin: SpinBox = $Panel/MarginContainer/Options/StrokeWidth/SpinBox

var _syncing := false

func _ready() -> void:
	fill_rect.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_open_color_picker("color_picker_fill", fill_rect.color, _on_fill_color_selected))

	stroke_rect.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_open_color_picker("color_picker_stroke", stroke_rect.color, _on_stroke_color_selected))

	stroke_width_spin.value_changed.connect(_on_stroke_width_changed)
	EditorState.selection_changed.connect(_on_selection_changed)
	EditorState.fill_stroke_changed.connect(_sync_from_editor_state)
	EditorState.playback_state_changed.connect(_on_playback_state_changed)
	_sync_from_editor_state()


## Mirrors the panel widgets to EditorState's current fill/stroke/width without
## re-committing to history (e.g. after a New Image reset).
func _sync_from_editor_state() -> void:
	if _syncing:
		return
	_syncing = true
	fill_rect.color = EditorState.current_fill_color
	stroke_rect.color = EditorState.current_stroke_color
	stroke_width_spin.value = EditorState.current_stroke_width
	_syncing = false


## Opens (or refocuses) the shared color picker for one swatch, syncing its
## selection to [param current] without emitting a spurious history commit.
func _open_color_picker(popup_id: String, current: Color, on_selected: Callable) -> void:
	var popup = PopupManager.open(popup_id, COLOR_POPUP_SCENE)
	if popup == null:
		return
	if not popup.color_selected.is_connected(on_selected):
		popup.color_selected.connect(on_selected)
	_syncing = true
	popup.select_color(current)
	_syncing = false


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



func _on_playback_state_changed(playing: bool) -> void:
	if not playing:
		_on_selection_changed(false)


func _on_selection_changed(_by_user: bool) -> void:
	if EditorState.is_playing:
		return
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
	fill_rect.color = shared_fill
	stroke_rect.color = shared_stroke
	stroke_width_spin.value = shared_width
	EditorState.set_current_fill_stroke(shared_fill, shared_stroke, shared_width)
	_syncing = false
