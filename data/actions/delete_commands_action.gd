class_name DeleteCommandsAction
extends EditAction

## Removes whole draw commands (layers) from a frame. Used by Cut and any future
## "delete layer" command. Stores the removed commands and their original indices
## so undo can re-insert them exactly where they were.

var _frame_index: int
## Array of Dictionaries: {cmd_idx, command}, kept sorted ascending by cmd_idx.
var _entries: Array = []

var _prev_selected_command_indices: Array[int]
var _prev_selected_point_indices: Dictionary


func _init(frame_index: int, command_indices: Array[int]) -> void:
	action_name = "Delete"
	_frame_index = frame_index

	_prev_selected_command_indices = EditorState.selected_command_indices.duplicate()
	_prev_selected_point_indices = {}
	for k in EditorState.selected_point_indices:
		_prev_selected_point_indices[k] = (EditorState.selected_point_indices[k] as Array).duplicate()

	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	if frame_index < 0 or frame_index >= sequence.frames.size():
		return
	var frame: DrawCommandImage = sequence.frames[frame_index]

	var sorted := command_indices.duplicate()
	sorted.sort()
	for idx: int in sorted:
		if idx < 0 or idx >= frame.commands.size():
			continue
		_entries.append({"cmd_idx": idx, "command": frame.commands[idx]})


func do_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	if _frame_index < 0 or _frame_index >= sequence.frames.size():
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]

	# Remove from highest index to lowest so earlier removals don't shift later ones.
	for i in range(_entries.size() - 1, -1, -1):
		var idx: int = _entries[i]["cmd_idx"]
		if idx >= 0 and idx < frame.commands.size():
			frame.commands.remove_at(idx)

	EditorState.selected_command_indices.clear()
	EditorState.selected_point_indices.clear()
	ProjectData.data_changed.emit(false, _frame_index)
	EditorState.selection_changed.emit(false)


func undo_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	if _frame_index < 0 or _frame_index >= sequence.frames.size():
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]

	# Re-insert from lowest index to highest so each command lands at its original slot.
	for entry in _entries:
		var idx: int = entry["cmd_idx"]
		var cmd: DrawCommand = entry["command"]
		frame.commands.insert(clampi(idx, 0, frame.commands.size()), cmd)

	EditorState.selected_command_indices = _prev_selected_command_indices.duplicate()
	EditorState.selected_point_indices = {}
	for k in _prev_selected_point_indices:
		EditorState.selected_point_indices[k] = (_prev_selected_point_indices[k] as Array).duplicate()
	ProjectData.data_changed.emit(false, _frame_index)
	EditorState.selection_changed.emit(false)
