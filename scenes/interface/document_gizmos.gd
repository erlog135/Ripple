extends Node2D

const GRID_COLOR := Color(0.5, 0.5, 0.5, 0.75)
const SKELLY_POINT_COLOR := GColor.WHITE
const SKELLY_SELECTED_POINT_COLOR := GColor.VERY_LIGHT_BLUE
const SKELLY_PATH_COLOR := Color(0.5, 0.5, 0.5, 1.0)
const SKELLY_SELECTED_PATH_COLOR := GColor.VERY_LIGHT_BLUE

const SKELLY_POINT_RADIUS_PX := 8.0
const SKELLY_PATH_WIDTH_PX := 1.0
const SELECTION_BOX_COLOR := Color(0.4, 0.7, 1.0, 0.85)


func _ready() -> void:
	ProjectData.data_changed.connect(_on_data_changed)
	EditorState.zoom_changed.connect(_on_zoom_changed)
	EditorState.selection_changed.connect(_on_selection_changed)

func _on_data_changed(_by_user: bool) -> void:
	queue_redraw()

func _on_zoom_changed(_screen_pos: Vector2, _factor: float) -> void:
	queue_redraw()

func _on_selection_changed(_by_user: bool) -> void:
	queue_redraw()

func _draw() -> void:
	if EditorState.current_zoom >= 10.0:
		_draw_pixel_grid()
	_draw_skeletons()
	_draw_selection_box()

func _draw_pixel_grid() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null or sequence.frames.is_empty():
		return

	var bounds: Vector2i = sequence.frames[0].bounds
	if bounds.x <= 0 or bounds.y <= 0:
		return

	for x in range(0, bounds.x+1):
		draw_line(Vector2(x, 0), Vector2(x, bounds.y), GRID_COLOR, 1.0 / EditorState.current_zoom)

	for y in range(0, bounds.y+1):
		draw_line(Vector2(0, y), Vector2(bounds.x, y), GRID_COLOR, 1.0 / EditorState.current_zoom)

func _draw_skeletons() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null or sequence.frames.is_empty():
		return

	var frame_idx := EditorState.current_frame
	if frame_idx >= sequence.frames.size():
		return

	var frame := sequence.frames[frame_idx]
	var line_w := SKELLY_PATH_WIDTH_PX / EditorState.current_zoom
	var pt_r := SKELLY_POINT_RADIUS_PX / EditorState.current_zoom

	for cmd_idx in range(frame.commands.size()):
		var cmd: DrawCommand = frame.commands[cmd_idx]
		if cmd.hidden:
			continue
		var sel_pts: Array = EditorState.selected_point_indices.get(cmd_idx, [])
		match cmd.draw_type:
			DrawCommand.Type.PATH, DrawCommand.Type.PRECISE_PATH:
				_draw_path_skeleton(cmd, sel_pts, line_w, pt_r)
			DrawCommand.Type.CIRCLE:
				_draw_circle_skeleton(cmd, sel_pts, line_w, pt_r)

func _draw_path_skeleton(cmd: DrawCommand, sel_pts: Array, line_w: float, pt_r: float) -> void:
	var n := cmd.points.size()
	if n == 0:
		return

	for i in range(n - 1):
		var seg_selected := (i in sel_pts) and ((i + 1) in sel_pts)
		var seg_color := SKELLY_SELECTED_PATH_COLOR if seg_selected else SKELLY_PATH_COLOR
		draw_line(cmd.points[i], cmd.points[i + 1], seg_color, line_w)

	if not cmd.path_open and n > 2:
		var seg_selected := ((n - 1) in sel_pts) and (0 in sel_pts)
		var seg_color := SKELLY_SELECTED_PATH_COLOR if seg_selected else SKELLY_PATH_COLOR
		draw_line(cmd.points[n - 1], cmd.points[0], seg_color, line_w)

	for i in range(n):
		var pt_color := SKELLY_SELECTED_POINT_COLOR if i in sel_pts else SKELLY_POINT_COLOR
		draw_circle(cmd.points[i], pt_r, pt_color)

func _draw_selection_box() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null or sequence.frames.is_empty():
		return
	var frame_idx := EditorState.current_frame
	if frame_idx >= sequence.frames.size():
		return
	var frame := sequence.frames[frame_idx]

	var selected_positions: Array[Vector2] = []
	for cmd_idx in EditorState.selected_point_indices:
		var cmd: DrawCommand = frame.commands[cmd_idx]
		if cmd.hidden:
			continue
		for pt_idx in EditorState.selected_point_indices[cmd_idx]:
			if pt_idx < cmd.points.size():
				selected_positions.append(cmd.points[pt_idx])

	if selected_positions.size() < 2:
		return

	var min_pos := selected_positions[0]
	var max_pos := selected_positions[0]
	for pos in selected_positions:
		min_pos = min_pos.min(pos)
		max_pos = max_pos.max(pos)

	var line_w := SKELLY_PATH_WIDTH_PX / EditorState.current_zoom
	var rect := Rect2(min_pos - Vector2(line_w, line_w), max_pos - min_pos + Vector2(line_w * 2.0, line_w * 2.0))
	draw_rect(rect, SELECTION_BOX_COLOR, false, line_w)

func get_point_at(world_pos: Vector2) -> Array:
	var sequence := ProjectData.current_sequence
	if sequence == null or sequence.frames.is_empty():
		return []
	var frame_idx := EditorState.current_frame
	if frame_idx >= sequence.frames.size():
		return []
	var frame := sequence.frames[frame_idx]
	var hit_radius := SKELLY_POINT_RADIUS_PX / EditorState.current_zoom
	var best_dist := hit_radius
	var best: Array = []
	for cmd_idx in range(frame.commands.size()):
		var cmd: DrawCommand = frame.commands[cmd_idx]
		if cmd.hidden:
			continue
		for pt_idx in range(cmd.points.size()):
			var dist := world_pos.distance_to(cmd.points[pt_idx])
			if dist < best_dist:
				best_dist = dist
				best = [cmd_idx, pt_idx]
	return best

func _draw_circle_skeleton(cmd: DrawCommand, sel_pts: Array, line_w: float, pt_r: float) -> void:
	if cmd.points.is_empty():
		return

	var center := cmd.points[0]
	var is_selected := 0 in sel_pts
	var outline_color := SKELLY_SELECTED_PATH_COLOR if is_selected else SKELLY_PATH_COLOR
	var pt_color := SKELLY_SELECTED_POINT_COLOR if is_selected else SKELLY_POINT_COLOR

	draw_arc(center, float(cmd.circle_radius), 0.0, TAU, 64, outline_color, line_w)
	draw_circle(center, pt_r, pt_color)