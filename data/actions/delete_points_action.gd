class_name DeletePointsAction
extends EditAction

var _frame_index: int
## Array of Dictionaries: {cmd_idx, old_points, new_points, old_path_open, new_path_open}
var _entries: Array = []

var _prev_selected_command_indices: Array[int]
var _prev_selected_point_indices: Dictionary


func _init(
	frame_index: int,
	point_selection: Dictionary,
	sel_commands: Array[int],
	sel_points: Dictionary,
) -> void:
	action_name = "Delete Points"
	_frame_index = frame_index
	_prev_selected_command_indices = sel_commands.duplicate()
	_prev_selected_point_indices = {}
	for k in sel_points:
		_prev_selected_point_indices[k] = (sel_points[k] as Array).duplicate()

	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	var frame: DrawCommandImage = sequence.frames[frame_index]

	for cmd_idx: int in point_selection.keys():
		var indices_to_delete: Array = point_selection[cmd_idx]
		if indices_to_delete.is_empty():
			continue
		if cmd_idx < 0 or cmd_idx >= frame.commands.size():
			continue
		var cmd: DrawCommand = frame.commands[cmd_idx]
		var old_pts := cmd.points
		var old_open: bool = cmd.path_open
		var new_open: bool = old_open
		var new_pts := PackedVector2Array()

		if not old_open:
			# Closed path: rotate the remaining points so the open seam falls at
			# the deletion site instead of at the arbitrary index-0/index-(n-1)
			# boundary. Start collecting from (last_deleted + 1) % n so that the
			# gap between the final and first surviving point is exactly where the
			# deleted point(s) were.
			var sorted_del := indices_to_delete.duplicate()
			sorted_del.sort()
			var last_del: int = sorted_del[sorted_del.size() - 1]
			var n := old_pts.size()
			var start := (last_del + 1) % n
			for step in range(n):
				var i := (start + step) % n
				if i not in indices_to_delete:
					new_pts.append(old_pts[i])
			# Opening the path only makes sense when points remain.
			if new_pts.size() > 0:
				new_open = true
		else:
			for i in range(old_pts.size()):
				if i not in indices_to_delete:
					new_pts.append(old_pts[i])
		var full_delete := new_pts.is_empty()
		_entries.append({
			"cmd_idx": cmd_idx,
			"old_points": old_pts,
			"new_points": new_pts,
			"old_path_open": old_open,
			"new_path_open": new_open,
			"full_delete": full_delete,
			"saved_cmd": cmd if full_delete else null,
		})


func do_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]
	for entry in _entries:
		if not entry["full_delete"]:
			var cmd: DrawCommand = frame.commands[entry["cmd_idx"]]
			cmd.points = entry["new_points"]
			cmd.path_open = entry["new_path_open"]
	var to_remove: Array[int] = []
	for entry in _entries:
		if entry["full_delete"]:
			to_remove.append(entry["cmd_idx"])
	to_remove.sort()
	to_remove.reverse()
	for idx in to_remove:
		frame.commands.remove_at(idx)
	EditorState.selected_command_indices.clear()
	EditorState.selected_point_indices.clear()
	ProjectData.data_changed.emit(false, _frame_index)
	EditorState.selection_changed.emit(false)


func undo_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]
	var to_insert := _entries.filter(func(e): return e["full_delete"])
	to_insert.sort_custom(func(a, b): return a["cmd_idx"] < b["cmd_idx"])
	for entry in to_insert:
		frame.commands.insert(entry["cmd_idx"], entry["saved_cmd"])
	for entry in _entries:
		if not entry["full_delete"]:
			var cmd: DrawCommand = frame.commands[entry["cmd_idx"]]
			cmd.points = entry["old_points"]
			cmd.path_open = entry["old_path_open"]
	EditorState.selected_command_indices = _prev_selected_command_indices.duplicate()
	EditorState.selected_point_indices = {}
	for k in _prev_selected_point_indices:
		EditorState.selected_point_indices[k] = (_prev_selected_point_indices[k] as Array).duplicate()
	ProjectData.data_changed.emit(false, _frame_index)
	EditorState.selection_changed.emit(false)
