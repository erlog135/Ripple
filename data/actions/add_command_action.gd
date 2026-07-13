class_name AddCommandAction
extends EditAction

var _frame_index: int
var _command: DrawCommand
var _insert_index: int

var _prev_selected_command_indices: Array[int]
var _prev_selected_point_indices: Dictionary


func _init(frame_index: int, command: DrawCommand, insert_index: int = -1) -> void:
	action_name = "Add Shape"
	_frame_index = frame_index
	_command = command

	_prev_selected_command_indices = EditorState.selected_command_indices.duplicate()
	_prev_selected_point_indices = {}
	for k in EditorState.selected_point_indices:
		_prev_selected_point_indices[k] = (EditorState.selected_point_indices[k] as Array).duplicate()

	var sequence := ProjectData.current_sequence
	if sequence != null and frame_index >= 0 and frame_index < sequence.frames.size():
		var frame: DrawCommandImage = sequence.frames[frame_index]
		if insert_index == -1:
			_insert_index = frame.commands.size()
		else:
			_insert_index = insert_index


func do_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null or _frame_index < 0 or _frame_index >= sequence.frames.size():
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]

	# Insert command
	frame.commands.insert(_insert_index, _command)

	# Select the new command and all its points
	EditorState.selected_command_indices = [_insert_index]
	var pt_indices := []
	for i in range(_command.points.size()):
		pt_indices.append(i)
	EditorState.selected_point_indices = {_insert_index: pt_indices}

	ProjectData.data_changed.emit(false, _frame_index)
	EditorState.selection_changed.emit(false)


func undo_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null or _frame_index < 0 or _frame_index >= sequence.frames.size():
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]

	# Remove command
	if _insert_index >= 0 and _insert_index < frame.commands.size():
		frame.commands.remove_at(_insert_index)

	# Restore selection
	EditorState.selected_command_indices = _prev_selected_command_indices.duplicate()
	EditorState.selected_point_indices = {}
	for k in _prev_selected_point_indices:
		EditorState.selected_point_indices[k] = (_prev_selected_point_indices[k] as Array).duplicate()

	ProjectData.data_changed.emit(false, _frame_index)
	EditorState.selection_changed.emit(false)
