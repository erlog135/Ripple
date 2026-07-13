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
		world_pos, DrawCommand.Type.CIRCLE, EditorState.current_stroke_width
	)
	_drag_start = snapped_start
	_dragging = true

	# Update editor state for preview rendering
	EditorState.update_shape_preview(
		true,
		EditorState.Tool.CIRCLE,
		PackedVector2Array(),
		_drag_start,
		0.0
	)


func handle_mouse_motion(world_pos: Vector2) -> void:
	if not _dragging:
		return

	var snapped_pos := EditorState.snap_world_position(
		world_pos, DrawCommand.Type.CIRCLE, EditorState.current_stroke_width
	)

	var alt := Input.is_key_pressed(KEY_ALT)
	var center: Vector2
	var radius: float

	if alt:
		center = _drag_start
		radius = _drag_start.distance_to(snapped_pos)
	else:
		center = (_drag_start + snapped_pos) / 2.0
		radius = _drag_start.distance_to(snapped_pos) / 2.0
		# Snap the midpoint center to the grid coordinates
		center = EditorState.snap_world_position(
			center, DrawCommand.Type.CIRCLE, EditorState.current_stroke_width
		)

	# Update editor state
	EditorState.update_shape_preview(
		true,
		EditorState.Tool.CIRCLE,
		PackedVector2Array(),
		center,
		radius
	)


func handle_left_release(world_pos: Vector2) -> void:
	if not _dragging:
		return

	_dragging = false
	EditorState.update_shape_preview(
		false,
		EditorState.Tool.CIRCLE,
		PackedVector2Array(),
		Vector2.ZERO,
		0.0
	)

	var snapped_pos := EditorState.snap_world_position(
		world_pos, DrawCommand.Type.CIRCLE, EditorState.current_stroke_width
	)

	var alt := Input.is_key_pressed(KEY_ALT)
	var center: Vector2
	var radius: int

	if alt:
		center = _drag_start
		radius = roundi(_drag_start.distance_to(snapped_pos))
	else:
		center = (_drag_start + snapped_pos) / 2.0
		radius = roundi(_drag_start.distance_to(snapped_pos) / 2.0)
		center = EditorState.snap_world_position(
			center, DrawCommand.Type.CIRCLE, EditorState.current_stroke_width
		)

	# Ensure radius is at least 1, otherwise discard the draw command (too small / click only)
	if radius < 1:
		return

	# Create the draw command
	var cmd := DrawCommand.new()
	cmd.draw_type = DrawCommand.Type.CIRCLE
	cmd.hidden = false
	cmd.stroke_color = EditorState.current_stroke_color
	cmd.stroke_width = EditorState.current_stroke_width
	cmd.fill_color = EditorState.current_fill_color
	cmd.path_open = false
	cmd.circle_radius = radius
	cmd.points = PackedVector2Array([center])

	# Commit the add command action
	var frame_idx := EditorState.current_frame
	HistoryManager.commit(AddCommandAction.new(frame_idx, cmd))


func cancel() -> void:
	if _dragging:
		_dragging = false
		EditorState.update_shape_preview(
			false,
			EditorState.Tool.CIRCLE,
			PackedVector2Array(),
			Vector2.ZERO,
			0.0
		)
