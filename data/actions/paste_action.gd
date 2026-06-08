class_name PasteAction
extends EditAction

## Appends clipboard commands to the top of the current frame's layer stack and
## selects them so the user can immediately drag the result. The commands are
## fetched (and offset) once at construction so do/undo/redo stay deterministic.

var _frame_index: int
var _commands_to_paste: Array[DrawCommand]
var _newly_added_indices: Array[int] = []

var _prev_selected_command_indices: Array[int]
var _prev_selected_point_indices: Dictionary


## [param paste_offset] nudges pasted geometry so it doesn't perfectly cover the
## originals. Callers pass Vector2.ZERO to paste in place (e.g. onto another frame).
## [param source_commands] supplies the commands to paste directly; when empty the
## clipboard is used. Duplicate passes freshly cloned selection commands here so it
## never touches the clipboard.
func _init(paste_offset: Vector2 = Vector2.ZERO, source_commands: Array[DrawCommand] = []) -> void:
	action_name = "Paste"
	_frame_index = EditorState.current_frame
	_commands_to_paste = source_commands if not source_commands.is_empty() else ClipboardManager.get_paste_data()

	if paste_offset != Vector2.ZERO:
		for cmd in _commands_to_paste:
			var shifted := cmd.points.duplicate()
			for i in range(shifted.size()):
				shifted[i] += paste_offset
			cmd.points = shifted

	_prev_selected_command_indices = EditorState.selected_command_indices.duplicate()
	_prev_selected_point_indices = {}
	for k in EditorState.selected_point_indices:
		_prev_selected_point_indices[k] = (EditorState.selected_point_indices[k] as Array).duplicate()


func do_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	if _frame_index < 0 or _frame_index >= sequence.frames.size():
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]

	_newly_added_indices.clear()
	var idx := frame.commands.size()
	for cmd in _commands_to_paste:
		frame.commands.append(cmd)
		_newly_added_indices.append(idx)
		idx += 1

	# Select the freshly pasted commands (and all of their points).
	EditorState.selected_command_indices = _newly_added_indices.duplicate()
	EditorState.selected_point_indices = {}
	for cmd_idx in _newly_added_indices:
		var cmd: DrawCommand = frame.commands[cmd_idx]
		var pts: Array[int] = []
		for p in range(cmd.points.size()):
			pts.append(p)
		EditorState.selected_point_indices[cmd_idx] = pts

	ProjectData.data_changed.emit(false, _frame_index)
	EditorState.selection_changed.emit(false)


func undo_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	if _frame_index < 0 or _frame_index >= sequence.frames.size():
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]

	# Pasted commands were appended contiguously at the end; remove high-to-low.
	for i in range(_newly_added_indices.size() - 1, -1, -1):
		var idx: int = _newly_added_indices[i]
		if idx >= 0 and idx < frame.commands.size():
			frame.commands.remove_at(idx)

	EditorState.selected_command_indices = _prev_selected_command_indices.duplicate()
	EditorState.selected_point_indices = {}
	for k in _prev_selected_point_indices:
		EditorState.selected_point_indices[k] = (_prev_selected_point_indices[k] as Array).duplicate()
	ProjectData.data_changed.emit(false, _frame_index)
	EditorState.selection_changed.emit(false)
