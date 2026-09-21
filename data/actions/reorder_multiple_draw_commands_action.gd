class_name ReorderMultipleDrawCommandsAction
extends EditAction

## Moves a group of draw commands (layers) to a new position as a single
## undoable action, preserving their relative order.
##
## Parameters
##   frame_index        – which frame to operate on
##   source_indices     – command indices to move (any order; will be sorted)
##   insert_before_idx  – command index before which the group should land
##                        (evaluated on the original array, before any removals)

var _frame_index: int

## Sorted ascending list of original command indices being moved.
var _source_indices: Array[int] = []

## Where (in the original array) to insert the group.
## The group is inserted so its first element ends up at this position,
## adjusted for the elements that were removed.
var _insert_before_idx: int

## Snapshots for undo.
var _prev_selected_command_indices: Array[int]
var _prev_selected_point_indices: Dictionary


func _init(frame_index: int, source_indices: Array[int], insert_before_idx: int) -> void:
	action_name = "Reorder Layers"
	_frame_index = frame_index
	_insert_before_idx = insert_before_idx

	# Snapshot editor selection so undo can restore it exactly.
	_prev_selected_command_indices = EditorState.selected_command_indices.duplicate()
	_prev_selected_point_indices = {}
	for k in EditorState.selected_point_indices:
		_prev_selected_point_indices[k] = (EditorState.selected_point_indices[k] as Array).duplicate()

	_source_indices = source_indices.duplicate()
	_source_indices.sort()


func do_action() -> void:
	var frame := _get_frame()
	if frame == null:
		return

	# Pull the moving commands out (highest index first to avoid shifting).
	var moving: Array = []
	for i in range(_source_indices.size() - 1, -1, -1):
		var idx: int = _source_indices[i]
		if idx < 0 or idx >= frame.commands.size():
			continue
		moving.push_front(frame.commands[idx])
		frame.commands.remove_at(idx)

	# Compute where to insert in the now-shorter array.
	# Every source index that was *below* _insert_before_idx shifts the insertion
	# point down by one (because its removal contracted the array).
	var adjusted_insert := _insert_before_idx
	for idx in _source_indices:
		if idx < _insert_before_idx:
			adjusted_insert -= 1
	adjusted_insert = clampi(adjusted_insert, 0, frame.commands.size())

	# Insert the group at the adjusted position in order.
	for i in range(moving.size()):
		frame.commands.insert(adjusted_insert + i, moving[i])

	# Remap selection: each source index maps to adjusted_insert + its rank.
	_apply_new_selection(adjusted_insert, frame)
	ProjectData.data_changed.emit(false, _frame_index)


func undo_action() -> void:
	var frame := _get_frame()
	if frame == null:
		return

	# Determine where do_action placed the group.
	var adjusted_insert := _insert_before_idx
	for idx in _source_indices:
		if idx < _insert_before_idx:
			adjusted_insert -= 1
	adjusted_insert = clampi(adjusted_insert, 0, frame.commands.size() - 1)

	# Remove them from where do_action put them (highest first).
	var group_size := _source_indices.size()
	var moving: Array = []
	for i in range(group_size - 1, -1, -1):
		var pos := adjusted_insert + i
		if pos < 0 or pos >= frame.commands.size():
			continue
		moving.push_front(frame.commands[pos])
		frame.commands.remove_at(pos)

	# Re-insert each command at its original index (lowest first).
	for i in range(_source_indices.size()):
		var original_idx: int = _source_indices[i]
		var insert_pos := clampi(original_idx, 0, frame.commands.size())
		if i < moving.size():
			frame.commands.insert(insert_pos, moving[i])

	# Restore previous selection.
	EditorState.selected_command_indices = _prev_selected_command_indices.duplicate()
	EditorState.selected_point_indices = {}
	for k in _prev_selected_point_indices:
		EditorState.selected_point_indices[k] = (_prev_selected_point_indices[k] as Array).duplicate()
	ProjectData.data_changed.emit(false, _frame_index)
	EditorState.selection_changed.emit(false)


func _get_frame() -> DrawCommandImage:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return null
	if _frame_index < 0 or _frame_index >= sequence.frames.size():
		return null
	return sequence.frames[_frame_index]


## After do_action, the moved group occupies [adjusted_insert, adjusted_insert + n-1].
func _apply_new_selection(adjusted_insert: int, frame: DrawCommandImage) -> void:
	if EditorState.current_frame != _frame_index:
		return

	var new_commands: Array[int] = []
	var new_points: Dictionary[int, Array] = {}
	for i in range(_source_indices.size()):
		var new_idx := adjusted_insert + i
		new_commands.append(new_idx)
		if new_idx >= 0 and new_idx < frame.commands.size():
			var cmd: DrawCommand = frame.commands[new_idx]
			var pts: Array[int] = []
			for pt_i in range(cmd.points.size()):
				pts.append(pt_i)
			new_points[new_idx] = pts
	EditorState.selected_command_indices = new_commands
	EditorState.selected_point_indices = new_points
	EditorState.selection_changed.emit(false)
