class_name DeleteFrameAction
extends EditAction

var _frame_index: int
var _saved_frame: DrawCommandImage
var _saved_duration_ms: int

var _saved_selected_command_indices: Array[int]
var _saved_selected_point_indices: Dictionary

## Frame the editor was navigated to after the deletion (set by the caller so
## undo can return to the correct position).
var _prev_frame: int


func _init(frame_index: int) -> void:
	action_name = "Delete Frame"
	_frame_index = frame_index

	var sequence := ProjectData.current_sequence
	if sequence == null or frame_index < 0 or frame_index >= sequence.frames.size():
		return

	_saved_frame = sequence.frames[frame_index]
	_saved_duration_ms = int(sequence.frame_durations_ms[frame_index])

	_saved_selected_command_indices = EditorState.selected_command_indices.duplicate()
	_saved_selected_point_indices = {}
	for k in EditorState.selected_point_indices:
		_saved_selected_point_indices[k] = (EditorState.selected_point_indices[k] as Array).duplicate()

	# Compute the frame the UI will land on after deletion so undo can revert it.
	_prev_frame = maxi(0, frame_index - 1)


func do_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	if _frame_index < 0 or _frame_index >= sequence.frames.size():
		return
	sequence.frames.remove_at(_frame_index)
	sequence.frame_durations_ms.remove_at(_frame_index)
	EditorState.selected_command_indices.clear()
	EditorState.selected_point_indices.clear()
	ProjectData.data_changed.emit(false, -1)
	EditorState.selection_changed.emit(false)


func undo_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	var idx := clampi(_frame_index, 0, sequence.frames.size())
	sequence.frames.insert(idx, _saved_frame)
	sequence.frame_durations_ms.insert(idx, _saved_duration_ms)

	# Restore selection before navigating so _validate_selection_for_new_frame
	# can check the now-present commands on the restored frame.
	EditorState.selected_command_indices = _saved_selected_command_indices.duplicate()
	EditorState.selected_point_indices = {}
	for k in _saved_selected_point_indices:
		EditorState.selected_point_indices[k] = (_saved_selected_point_indices[k] as Array).duplicate()

	ProjectData.data_changed.emit(false, -1)
	EditorState.set_current_frame(idx)
