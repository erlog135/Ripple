class_name DrawCommandPropertyAction
extends EditAction

var _frame_index: int
var _command_indices: Array[int]
var _property: StringName
var _old_values: Array = []
var _use_parallel: bool
var _uniform_new: Variant
var _parallel_new: Array


func _init(
		action_title: String,
		frame_index: int,
		command_indices: Array[int],
		property: StringName,
		uniform_new: Variant = null,
		parallel_new: Array = [],
	) -> void:
	action_name = action_title
	_frame_index = frame_index
	_command_indices = command_indices.duplicate()
	_property = property
	_use_parallel = not parallel_new.is_empty()
	_uniform_new = uniform_new
	_parallel_new = parallel_new.duplicate()
	if _use_parallel:
		assert(
			parallel_new.size() == _command_indices.size(),
			"parallel_new length must match command_indices",
		)
	var sequence := ProjectData.current_sequence
	if not sequence:
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]
	for idx in _command_indices:
		_old_values.append(frame.commands[idx].get(_property))


func _new_value_at(i: int) -> Variant:
	if _use_parallel:
		return _parallel_new[i]
	return _uniform_new


func do_action() -> void:
	var sequence := ProjectData.current_sequence
	if not sequence:
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]
	for i in range(_command_indices.size()):
		var idx := _command_indices[i]
		var cmd: DrawCommand = frame.commands[idx]
		cmd.set(_property, _new_value_at(i))
	ProjectData.data_changed.emit(false, _frame_index)


func undo_action() -> void:
	var sequence := ProjectData.current_sequence
	if not sequence:
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]
	for i in range(_command_indices.size()):
		var idx := _command_indices[i]
		var cmd: DrawCommand = frame.commands[idx]
		cmd.set(_property, _old_values[i])
	ProjectData.data_changed.emit(false, _frame_index)
