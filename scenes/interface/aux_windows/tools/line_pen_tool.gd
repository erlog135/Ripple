extends RefCounted


func handle_mouse_motion(world_pos: Vector2) -> void:
	var frame: DrawCommandImage = ProjectData.get_current_image()
	var rb: Dictionary = line_pen_rubber_band_context(frame)
	var draw_type: DrawCommand.Type
	var stroke_w: int
	if rb.is_empty():
		draw_type = DrawCommand.Type.PRECISE_PATH
		stroke_w = EditorState.current_stroke_width
	else:
		var cmd_rb: DrawCommand = rb[&"cmd"]
		draw_type = cmd_rb.draw_type
		stroke_w = cmd_rb.stroke_width
	EditorState.update_line_pen_hover_world(EditorState.snap_world_position(world_pos, draw_type, stroke_w))


func handle_left_press(world_pos: Vector2, gizmos) -> void:
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return

	var frame_idx := EditorState.current_frame
	var sel_cmds := EditorState.selected_command_indices.duplicate()
	var sel_pts := EditorState.selected_point_indices.duplicate()

	var ctx: Dictionary = normalized_pen_selection(frame)

	if ctx.is_empty():
		var snap_new: Vector2 = EditorState.snap_world_position(
			world_pos,
			DrawCommand.Type.PRECISE_PATH,
			EditorState.current_stroke_width,
		)
		HistoryManager.commit(LinePenEditAction.start_new(frame_idx, snap_new, sel_cmds, sel_pts))
		return

	var cmd_idx: int = ctx[&"cmd_idx"]
	var cmd: DrawCommand = ctx[&"cmd"]
	var pt_indices: Array = ctx[&"pts"]
	var snapped_work: Vector2 = EditorState.snap_world_position(world_pos, cmd.draw_type, cmd.stroke_width)

	if pt_indices.size() == 1:
		var i: int = pt_indices[0]
		var n := cmd.points.size()

		var should_close := false
		if cmd.path_open and n >= 2 and (i == 0 or i == n - 1):
			var j := n - 1 if i == 0 else 0
			var hit: Array = gizmos.call(&"get_point_at", world_pos)
			var hit_correct := (
				hit.size() >= 2
				and int(hit[0]) == cmd_idx
				and int(hit[1]) == j
			)
			var snaps_to_close: bool = snapped_work.is_equal_approx(cmd.points[j])
			should_close = hit_correct or snaps_to_close

		if should_close:
			HistoryManager.commit(LinePenEditAction.close_path(frame_idx, cmd_idx, sel_cmds, sel_pts))
			return

		if i == n - 1:
			HistoryManager.commit(LinePenEditAction.insert_point(frame_idx, cmd_idx, n, snapped_work, sel_cmds, sel_pts))
			return

		if i == 0:
			HistoryManager.commit(LinePenEditAction.insert_point(frame_idx, cmd_idx, 0, snapped_work, sel_cmds, sel_pts))
			return

		HistoryManager.commit(
			LinePenEditAction.start_new(
				frame_idx,
				EditorState.snap_world_position(world_pos, DrawCommand.Type.PRECISE_PATH, EditorState.current_stroke_width),
				sel_cmds,
				sel_pts,
			),
		)
		return

	if pt_indices.size() == 2:
		var lo: int = pt_indices[0]
		var hi: int = pt_indices[1]
		if lo > hi:
			var tmp := lo
			lo = hi
			hi = tmp

		var n2 := cmd.points.size()
		var insert_at := -1
		if hi - lo == 1:
			insert_at = hi
		elif not cmd.path_open and lo == 0 and hi == n2 - 1:
			insert_at = n2
		else:
			HistoryManager.commit(
				LinePenEditAction.start_new(
					frame_idx,
					EditorState.snap_world_position(world_pos, DrawCommand.Type.PRECISE_PATH, EditorState.current_stroke_width),
					sel_cmds,
					sel_pts,
				),
			)
			return

		HistoryManager.commit(LinePenEditAction.insert_point(frame_idx, cmd_idx, insert_at, snapped_work, sel_cmds, sel_pts))
		return

	HistoryManager.commit(
		LinePenEditAction.start_new(
			frame_idx,
			EditorState.snap_world_position(world_pos, DrawCommand.Type.PRECISE_PATH, EditorState.current_stroke_width),
			sel_cmds,
			sel_pts,
		),
	)


static func normalized_pen_selection(frame: DrawCommandImage) -> Dictionary:
	if frame == null:
		return {}

	if EditorState.selected_command_indices.size() != 1:
		return {}

	var cmd_idx: int = EditorState.selected_command_indices[0]

	for k in EditorState.selected_point_indices:
		if int(k) != cmd_idx:
			return {}

	if cmd_idx not in EditorState.selected_point_indices:
		return {}

	if cmd_idx < 0 or cmd_idx >= frame.commands.size():
		return {}

	var cmd: DrawCommand = frame.commands[cmd_idx]
	if cmd.hidden:
		return {}

	if cmd.draw_type != DrawCommand.Type.PATH and cmd.draw_type != DrawCommand.Type.PRECISE_PATH:
		return {}

	var pts_raw: Array = EditorState.selected_point_indices[cmd_idx]
	var pts: Array = _dedupe_point_indices_sorted(pts_raw, cmd.points.size())

	if pts.is_empty():
		return {}

	if pts.size() > 2:
		return {}

	if pts.size() == 2:
		var lo: int = pts[0]
		var hi: int = pts[1]
		var n := cmd.points.size()
		var adjacent := (hi - lo == 1) or (
			not cmd.path_open and lo == 0 and hi == n - 1
		)
		if not adjacent:
			return {}

	return {
		&"cmd_idx": cmd_idx,
		&"cmd": cmd,
		&"pts": pts,
	}


## Selection context for drawing the rubber band: endpoint + two-point segment only (not a lone interior vertex).
static func line_pen_rubber_band_context(frame: DrawCommandImage) -> Dictionary:
	var ctx: Dictionary = normalized_pen_selection(frame)
	if ctx.is_empty():
		return {}
	var pts: Array = ctx[&"pts"]
	if pts.size() == 2:
		return ctx
	var cmd: DrawCommand = ctx[&"cmd"]
	var i: int = int(pts[0])
	var n := cmd.points.size()
	if i == 0 or i == n - 1:
		return ctx
	return {}


static func _dedupe_point_indices_sorted(raw: Array, point_count: int) -> Array:
	var uniq: Dictionary = {}
	var out: Array = []
	for x in raw:
		if not (x is int):
			continue
		var xi := int(x)
		if xi < 0 or xi >= point_count:
			continue
		if uniq.has(xi):
			continue
		uniq[xi] = true
		out.append(xi)
	out.sort()
	return out
