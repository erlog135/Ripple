class_name TransformSelectionAction
extends EditAction


## Applies a committed transform (move/scale/rotate) to selected commands.[br]
## [param new_points_arrays] and [param new_radii] align with [param command_indices]
## (same length, same order). A radius entry < 0 means "leave the circle radius unchanged".


var _frame_index: int
var _command_indices: Array[int]
var _new_points: Array = []
var _new_radii: Array = []
var _old_points: Array = []
var _old_radii: Array = []
## Command indices whose path_open should be set to false (endpoint-merge close).
var _close_indices: Array[int] = []
var _close_old_path_open: Array[bool] = []


func _init(
		frame_index: int,
		command_indices: Array[int],
		new_points_arrays: Array,
		new_radii: Array,
		close_indices: Array[int] = [],
	) -> void:
	action_name = "Transform"
	_frame_index = frame_index
	_command_indices = command_indices.duplicate()
	_new_points = new_points_arrays.duplicate()
	_new_radii = new_radii.duplicate()
	_close_indices = close_indices.duplicate()

	var sequence := ProjectData.current_sequence
	if not sequence:
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]
	for idx in _command_indices:
		var cmd: DrawCommand = frame.commands[idx]
		_old_points.append(cmd.points.duplicate())
		_old_radii.append(cmd.circle_radius)
	for idx in _close_indices:
		_close_old_path_open.append((frame.commands[idx] as DrawCommand).path_open)


func do_action() -> void:
	var sequence := ProjectData.current_sequence
	if not sequence:
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]
	for i in range(_command_indices.size()):
		var cmd: DrawCommand = frame.commands[_command_indices[i]]
		cmd.points = _new_points[i]
		if int(_new_radii[i]) >= 0:
			cmd.circle_radius = int(_new_radii[i])
	for idx in _close_indices:
		(frame.commands[idx] as DrawCommand).path_open = false
	ProjectData.data_changed.emit(false, _frame_index)


func undo_action() -> void:
	var sequence := ProjectData.current_sequence
	if not sequence:
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]
	for i in range(_command_indices.size()):
		var cmd: DrawCommand = frame.commands[_command_indices[i]]
		cmd.points = _old_points[i]
		cmd.circle_radius = int(_old_radii[i])
	for i in range(_close_indices.size()):
		(frame.commands[_close_indices[i]] as DrawCommand).path_open = _close_old_path_open[i]
	ProjectData.data_changed.emit(false, _frame_index)
