extends RefCounted

var _dragging := false
var _drag_start := Vector2.ZERO


func handle_left_press(world_pos: Vector2) -> void:
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return

	# Clear selection at start of draw
	EditorState.clear_selection()

	# Snap the starting position
	var snapped_start := EditorState.snap_world_position(
		world_pos, DrawCommand.Type.PRECISE_PATH, EditorState.current_stroke_width
	)
	_drag_start = snapped_start
	_dragging = true

	# Update editor state for preview rendering
	var initial_pts := PackedVector2Array([_drag_start, _drag_start, _drag_start, _drag_start])
	EditorState.update_shape_preview(
		true,
		EditorState.Tool.RECTANGLE,
		initial_pts,
		Vector2.ZERO,
		0.0
	)


func handle_mouse_motion(world_pos: Vector2) -> void:
	if not _dragging:
		return

	var snapped_pos := EditorState.snap_world_position(
		world_pos, DrawCommand.Type.PRECISE_PATH, EditorState.current_stroke_width
	)

	var alt := Input.is_key_pressed(KEY_ALT)
	var shift := Input.is_key_pressed(KEY_SHIFT)

	var points := _calculate_rect_points(_drag_start, snapped_pos, alt, shift)

	# Update editor state
	EditorState.update_shape_preview(
		true,
		EditorState.Tool.RECTANGLE,
		points,
		Vector2.ZERO,
		0.0
	)


func handle_left_release(world_pos: Vector2) -> void:
	if not _dragging:
		return

	_dragging = false
	EditorState.update_shape_preview(
		false,
		EditorState.Tool.RECTANGLE,
		PackedVector2Array(),
		Vector2.ZERO,
		0.0
	)

	var snapped_pos := EditorState.snap_world_position(
		world_pos, DrawCommand.Type.PRECISE_PATH, EditorState.current_stroke_width
	)

	var alt := Input.is_key_pressed(KEY_ALT)
	var ctrl := Input.is_key_pressed(KEY_CTRL)

	var points := _calculate_rect_points(_drag_start, snapped_pos, alt, ctrl)

	# Ensure the rectangle is not degenerate (opposite corners are not equal)
	# This avoids single-point or zero-size rectangle additions.
	if points[0] == points[2]:
		return

	# Create the draw command
	var cmd := DrawCommand.new()
	cmd.draw_type = DrawCommand.Type.PRECISE_PATH
	cmd.hidden = false
	cmd.stroke_color = EditorState.current_stroke_color
	cmd.stroke_width = EditorState.current_stroke_width
	cmd.fill_color = EditorState.current_fill_color
	cmd.path_open = false
	cmd.circle_radius = 0
	cmd.points = points

	# Commit the add command action
	var frame_idx := EditorState.current_frame
	HistoryManager.commit(AddCommandAction.new(frame_idx, cmd))


func cancel() -> void:
	if _dragging:
		_dragging = false
		EditorState.update_shape_preview(
			false,
			EditorState.Tool.RECTANGLE,
			PackedVector2Array(),
			Vector2.ZERO,
			0.0
		)


func _calculate_rect_points(start: Vector2, current: Vector2, alt: bool, ctrl: bool) -> PackedVector2Array:
	var x1: float
	var y1: float
	var x2: float
	var y2: float

	if alt:
		var half_size := current - start
		if ctrl:
			var size := maxf(absf(half_size.x), absf(half_size.y))
			x1 = start.x - size
			x2 = start.x + size
			y1 = start.y - size
			y2 = start.y + size
		else:
			var hx := absf(half_size.x)
			var hy := absf(half_size.y)
			x1 = start.x - hx
			x2 = start.x + hx
			y1 = start.y - hy
			y2 = start.y + hy
	else:
		if ctrl:
			var delta := current - start
			var size := maxf(absf(delta.x), absf(delta.y))
			var sx := 1.0 if delta.x >= 0.0 else -1.0
			var sy := 1.0 if delta.y >= 0.0 else -1.0
			var endpoint := start + Vector2(size * sx, size * sy)
			x1 = minf(start.x, endpoint.x)
			x2 = maxf(start.x, endpoint.x)
			y1 = minf(start.y, endpoint.y)
			y2 = maxf(start.y, endpoint.y)
		else:
			x1 = minf(start.x, current.x)
			x2 = maxf(start.x, current.x)
			y1 = minf(start.y, current.y)
			y2 = maxf(start.y, current.y)

	return PackedVector2Array([
		Vector2(x1, y1),
		Vector2(x2, y1),
		Vector2(x2, y2),
		Vector2(x1, y2)
	])
