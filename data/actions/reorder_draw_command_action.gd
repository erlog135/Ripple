class_name ReorderDrawCommandAction
extends EditAction

var _frame_index: int
var _from_index: int
var _to_index: int


func _init(frame_index: int, from_index: int, to_index: int) -> void:
	action_name = "Reorder Layer"
	_frame_index = frame_index
	_from_index = from_index
	_to_index = to_index


func do_action() -> void:
	var frame := _get_frame()
	if frame == null:
		return
	var effective_to := _effective_insert_index(frame.commands.size(), _to_index)
	_move_command(frame.commands, _from_index, _to_index)
	_remap_editor_selection(_from_index, effective_to)
	ProjectData.data_changed.emit(false)


func undo_action() -> void:
	var frame := _get_frame()
	if frame == null:
		return
	var effective_from := _effective_insert_index(frame.commands.size(), _from_index)
	_move_command(frame.commands, _to_index, _from_index)
	_remap_editor_selection(effective_from, _from_index)
	ProjectData.data_changed.emit(false)


func _get_frame() -> DrawCommandImage:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return null
	if _frame_index < 0 or _frame_index >= sequence.frames.size():
		return null
	return sequence.frames[_frame_index]


func _move_command(commands: Array, from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= commands.size():
		return
	var command: DrawCommand = commands[from_index]
	commands.remove_at(from_index)
	var insert_index := clampi(to_index, 0, commands.size())
	commands.insert(insert_index, command)


func _effective_insert_index(command_count: int, to_index: int) -> int:
	if command_count <= 0:
		return 0
	return clampi(to_index, 0, command_count - 1)


func _remap_editor_selection(from_index: int, to_index: int) -> void:
	if EditorState.current_frame != _frame_index:
		return

	var remapped_commands: Array[int] = []
	for command_index in EditorState.selected_command_indices:
		remapped_commands.append(_remap_index(command_index, from_index, to_index))
	EditorState.selected_command_indices = remapped_commands

	var remapped_points: Dictionary[int, Array] = {}
	for command_index in EditorState.selected_point_indices:
		var remapped_index := _remap_index(command_index, from_index, to_index)
		remapped_points[remapped_index] = EditorState.selected_point_indices[command_index]
	EditorState.selected_point_indices = remapped_points
	EditorState.selection_changed.emit(false)


func _remap_index(index: int, from_index: int, to_index: int) -> int:
	if from_index == to_index:
		return index
	if index == from_index:
		return to_index
	if from_index < to_index:
		if index > from_index and index <= to_index:
			return index - 1
		return index
	if index >= to_index and index < from_index:
		return index + 1
	return index
