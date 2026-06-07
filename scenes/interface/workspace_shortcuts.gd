extends Node

func _unhandled_key_input(event: InputEvent) -> void:
	# Ignore releases to prevent double-firing
	if not event.is_pressed():
		return 

	# --- TOOL SWITCHING ---
	if event.is_action("tool_select"):
		EditorState.change_tool(EditorState.Tool.SELECT)
	elif event.is_action("tool_transform"):
		EditorState.change_tool(EditorState.Tool.TRANSFORM)
	elif event.is_action("tool_line_pen"):
		EditorState.change_tool(EditorState.Tool.LINE_PEN)
	elif event.is_action("tool_circle"):
		EditorState.change_tool(EditorState.Tool.CIRCLE)
	elif event.is_action("tool_rectangle"):
		EditorState.change_tool(EditorState.Tool.RECTANGLE)
	elif event.is_action("tool_pan"):
		EditorState.change_tool(EditorState.Tool.PAN)
		
	# --- TIMELINE NAVIGATION ---
	elif event.is_action("animation_frame_next"):
		EditorState.set_current_frame(EditorState.current_frame + 1)
	elif event.is_action("animation_frame_prev"):
		EditorState.set_current_frame(EditorState.current_frame - 1)
		
	# --- NUDGING ---
	elif event.is_action("nudge_up"):
		_nudge_selection(Vector2(0, -1))
	elif event.is_action("nudge_down"):
		_nudge_selection(Vector2(0, 1))
	elif event.is_action("nudge_left"):
		_nudge_selection(Vector2(-1, 0))
	elif event.is_action("nudge_right"):
		_nudge_selection(Vector2(1, 0))


func _nudge_selection(delta: Vector2) -> void:
	if EditorState.selected_command_indices.is_empty():
		return
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return

	var command_indices: Array[int] = []
	var new_points_arrays: Array = []
	var new_radii: Array = []

	for cmd_idx in EditorState.selected_command_indices:
		if cmd_idx < 0 or cmd_idx >= frame.commands.size():
			continue
		var cmd: DrawCommand = frame.commands[cmd_idx]
		var shifted := cmd.points.duplicate()
		var sel_pts: Array = EditorState.selected_point_indices.get(cmd_idx, [])
		var indices_to_move: Array = sel_pts if not sel_pts.is_empty() else range(cmd.points.size())
		for pt_idx in indices_to_move:
			if pt_idx < shifted.size():
				shifted[pt_idx] = shifted[pt_idx] + delta
		command_indices.append(cmd_idx)
		new_points_arrays.append(shifted)
		new_radii.append(-1)

	if command_indices.is_empty():
		return

	HistoryManager.commit(TransformSelectionAction.new(
		EditorState.current_frame, command_indices, new_points_arrays, new_radii
	))
