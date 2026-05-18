extends RefCounted

var _drag_start_world := Vector2.ZERO
var _dragging := false

# Each entry: { "cmd_idx": int, "pt_idx": int, "original_pos": Vector2,
#               "draw_type": DrawCommand.Type, "stroke_width": int }
var _selected_snapshot: Array = []

# The snapshot entry for the selected point closest to the drag start.
var _anchor: Dictionary = {}


func handle_left_press(world_pos: Vector2) -> void:
	if EditorState.selected_command_indices.is_empty():
		return
	_drag_start_world = world_pos
	_dragging = true
	_cache_selected_snapshot()
	EditorState.update_drag(Vector2.ZERO, true)


func handle_mouse_motion(world_pos: Vector2) -> void:
	if not _dragging:
		return
	EditorState.update_drag(_compute_snapped_offset(world_pos), true)


func handle_left_release(world_pos: Vector2) -> void:
	if not _dragging:
		return

	var snapped_offset := _compute_snapped_offset(world_pos)
	if snapped_offset != Vector2.ZERO:
		_commit_drag(snapped_offset)

	_dragging = false
	_selected_snapshot.clear()
	_anchor.clear()
	EditorState.update_drag(Vector2.ZERO, false)


func cancel() -> void:
	_dragging = false
	_selected_snapshot.clear()
	_anchor.clear()
	EditorState.update_drag(Vector2.ZERO, false)


func _cache_selected_snapshot() -> void:
	_selected_snapshot.clear()
	_anchor.clear()
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return

	for cmd_idx in EditorState.selected_command_indices:
		if cmd_idx >= frame.commands.size():
			continue
		var selected_pts: Array = EditorState.selected_point_indices.get(cmd_idx, [])
		if selected_pts.is_empty():
			continue
		var cmd: DrawCommand = frame.commands[cmd_idx]
		for pt_idx in selected_pts:
			if pt_idx >= 0 and pt_idx < cmd.points.size():
				_selected_snapshot.append({
					"cmd_idx": cmd_idx,
					"pt_idx": pt_idx,
					"original_pos": cmd.points[pt_idx],
					"draw_type": cmd.draw_type,
					"stroke_width": cmd.stroke_width,
				})

	if _selected_snapshot.is_empty():
		return

	# Anchor is the point whose original position is closest to the drag start.
	# Because every selected point shifts by the same raw offset, the
	# cursor-to-point distance stays constant throughout the drag, so the
	# anchor never needs to be recomputed mid-drag.
	var best_dist_sq := INF
	for entry in _selected_snapshot:
		var d: float = _drag_start_world.distance_squared_to(entry["original_pos"])
		if d < best_dist_sq:
			best_dist_sq = d
			_anchor = entry


func _compute_snapped_offset(world_pos: Vector2) -> Vector2:
	if _anchor.is_empty():
		return world_pos - _drag_start_world

	var raw_offset := world_pos - _drag_start_world
	var anchor_new: Vector2 = _anchor["original_pos"] + raw_offset
	var snapped: Vector2 = EditorState.snap_world_position(
		anchor_new,
		_anchor["draw_type"],
		_anchor["stroke_width"],
	)
	return snapped - _anchor["original_pos"]


func _commit_drag(total_offset: Vector2) -> void:
	var frame_idx := EditorState.current_frame
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return

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
