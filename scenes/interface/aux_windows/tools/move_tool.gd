extends RefCounted

var _drag_start_world := Vector2.ZERO
var _dragging := false


func handle_left_press(world_pos: Vector2) -> void:
	if EditorState.selected_command_indices.is_empty():
		return
	_drag_start_world = world_pos
	_dragging = true
	EditorState.update_drag(Vector2.ZERO, true)

func handle_mouse_motion(world_pos: Vector2) -> void:
	if not _dragging:
		return
	EditorState.update_drag(world_pos - _drag_start_world, true)

func handle_left_release(world_pos: Vector2) -> void:
	if not _dragging:
		return

	var total_offset := world_pos - _drag_start_world
	if total_offset != Vector2.ZERO:
		_commit_drag(total_offset)

	_dragging = false
	EditorState.update_drag(Vector2.ZERO, false)

func cancel() -> void:
	_dragging = false
	EditorState.update_drag(Vector2.ZERO, false)

func _commit_drag(total_offset: Vector2) -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null or sequence.frames.is_empty():
		return
	var frame_idx := EditorState.current_frame
	if frame_idx >= sequence.frames.size():
		return
	var frame: DrawCommandImage = sequence.frames[frame_idx]

	var command_indices: Array[int] = []
	var moved_points_arrays: Array = []

	for cmd_idx in EditorState.selected_command_indices:
		if cmd_idx >= frame.commands.size():
			continue
		var selected_pts: Array = EditorState.selected_point_indices.get(cmd_idx, [])
		if selected_pts.is_empty():
			continue

		var cmd: DrawCommand = frame.commands[cmd_idx]
		var new_points: PackedVector2Array = cmd.points.duplicate()
		for pt_idx in selected_pts:
			if pt_idx >= 0 and pt_idx < new_points.size():
				new_points[pt_idx] += total_offset

		command_indices.append(cmd_idx)
		moved_points_arrays.append(new_points)

	if command_indices.is_empty():
		return

	HistoryManager.commit(SetDrawCommandPointsAction.new(frame_idx, command_indices, moved_points_arrays))
