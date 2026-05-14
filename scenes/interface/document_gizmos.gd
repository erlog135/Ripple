extends Node2D

const GRID_COLOR := Color(0.5, 0.5, 0.5, 0.75)
const SKELLY_POINT_COLOR := GColor.WHITE
const SKELLY_SELECTED_POINT_COLOR := GColor.VERY_LIGHT_BLUE
const SKELLY_PATH_COLOR := Color(0.5, 0.5, 0.5, 1.0)
const SKELLY_SELECTED_PATH_COLOR := GColor.VERY_LIGHT_BLUE

const SKELLY_POINT_RADIUS_PX := 8.0
const SKELLY_PATH_WIDTH_PX := 2.0
const SELECTION_BOX_COLOR := Color(0.4, 0.7, 1.0, 0.85)
const DRAG_SELECTION_BOX_COLOR := Color(0.4, 0.7, 1.0, 0.45)
const LINE_PEN_PREVIEW_COLOR := Color(0.0, 0.5, 1.0, 0.8)
const PenToolScr = preload("res://scenes/interface/aux_windows/tools/line_pen_tool.gd")

var _drag_selection_rect := Rect2()
var _drag_selection_active := false


func _ready() -> void:
	ProjectData.data_changed.connect(_on_data_changed)
	EditorState.current_frame_changed.connect(_on_current_frame_changed)
	EditorState.zoom_changed.connect(_on_zoom_changed)
	EditorState.selection_changed.connect(_on_selection_changed)
	EditorState.tool_changed.connect(_on_tool_changed)
	EditorState.drag_updated.connect(_on_drag_updated)
	EditorState.line_pen_hover_changed.connect(_on_line_pen_hover_changed)

func _on_data_changed(_by_user: bool) -> void:
	queue_redraw()


func _on_current_frame_changed(_frame: int) -> void:
	queue_redraw()


func _on_zoom_changed(_screen_pos: Vector2, _factor: float) -> void:
	queue_redraw()

func _on_selection_changed(_by_user: bool) -> void:
	queue_redraw()

func _on_tool_changed(_tool: EditorState.Tool) -> void:
	queue_redraw()

func _on_drag_updated(_offset: Vector2, _dragging: bool) -> void:
	queue_redraw()

func _on_line_pen_hover_changed() -> void:
	queue_redraw()

func _draw() -> void:
	if EditorState.is_playing:
		return
	if EditorState.current_zoom >= 10.0:
		_draw_pixel_grid()
	_draw_skeletons()
	_draw_line_pen_preview()
	_draw_drag_selection_box()
	_draw_selection_box()

func _draw_pixel_grid() -> void:
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return

	var bounds: Vector2i = frame.bounds
	if bounds.x <= 0 or bounds.y <= 0:
		return

	for x in range(0, bounds.x+1):
		draw_line(Vector2(x, 0), Vector2(x, bounds.y), GRID_COLOR, 1.0 / EditorState.current_zoom)

	for y in range(0, bounds.y+1):
		draw_line(Vector2(0, y), Vector2(bounds.x, y), GRID_COLOR, 1.0 / EditorState.current_zoom)

func _draw_skeletons() -> void:
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return

	var line_w := SKELLY_PATH_WIDTH_PX / EditorState.current_zoom
	var pt_r := SKELLY_POINT_RADIUS_PX / EditorState.current_zoom
	var show_only_selected := EditorState.active_tool != EditorState.Tool.SELECT

	for cmd_idx in range(frame.commands.size()):
		var cmd: DrawCommand = frame.commands[cmd_idx]
		if cmd.hidden:
			continue
		var sel_pts: Array = EditorState.selected_point_indices.get(cmd_idx, [])
		if show_only_selected and sel_pts.is_empty():
			continue
		match cmd.draw_type:
			DrawCommand.Type.PATH, DrawCommand.Type.PRECISE_PATH:
				_draw_path_skeleton(cmd, cmd_idx, sel_pts, line_w, pt_r, show_only_selected)
			DrawCommand.Type.CIRCLE:
				_draw_circle_skeleton(cmd, cmd_idx, sel_pts, line_w, pt_r, show_only_selected)


func _draw_line_pen_preview() -> void:
	if EditorState.active_tool != EditorState.Tool.LINE_PEN:
		return
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return
	var ctx: Dictionary = PenToolScr.line_pen_rubber_band_context(frame)
	if ctx.is_empty():
		return
	var cmd_idx: int = ctx[&"cmd_idx"]
	if cmd_idx < 0 or cmd_idx >= frame.commands.size():
		return
	var cmd: DrawCommand = frame.commands[cmd_idx]
	var pts: Array = ctx[&"pts"]
	var hover: Vector2 = EditorState.line_pen_hover_world
	var line_w := SKELLY_PATH_WIDTH_PX / EditorState.current_zoom
	if pts.size() == 1:
		var pi: int = int(pts[0])
		if pi < 0 or pi >= cmd.points.size():
			return
		var a := _point_with_drag_offset(cmd.points[pi], cmd_idx, pi)
		draw_line(a, hover, LINE_PEN_PREVIEW_COLOR, line_w)
	elif pts.size() == 2:
		var ia := int(pts[0])
		var ib := int(pts[1])
		if ia < 0 or ia >= cmd.points.size() or ib < 0 or ib >= cmd.points.size():
			return
		var pa := _point_with_drag_offset(cmd.points[ia], cmd_idx, ia)
		var pb := _point_with_drag_offset(cmd.points[ib], cmd_idx, ib)
		draw_line(pa, hover, LINE_PEN_PREVIEW_COLOR, line_w)
		draw_line(hover, pb, LINE_PEN_PREVIEW_COLOR, line_w)


func _draw_path_skeleton(cmd: DrawCommand, cmd_idx: int, sel_pts: Array, line_w: float, pt_r: float, show_only_selected: bool) -> void:
	var points := _points_with_drag_offset(cmd.points, cmd_idx)
	var n := points.size()
	if n == 0:
		return

	for i in range(n - 1):
		var seg_selected := (i in sel_pts) and ((i + 1) in sel_pts)
		if show_only_selected and not seg_selected:
			continue
		var seg_color := SKELLY_SELECTED_PATH_COLOR if seg_selected else SKELLY_PATH_COLOR
		draw_line(points[i], points[i + 1], seg_color, line_w)

	if not cmd.path_open and n > 2:
		var seg_selected := ((n - 1) in sel_pts) and (0 in sel_pts)
		if not show_only_selected or seg_selected:
			var seg_color := SKELLY_SELECTED_PATH_COLOR if seg_selected else SKELLY_PATH_COLOR
			draw_line(points[n - 1], points[0], seg_color, line_w)

	for i in range(n):
		if show_only_selected and not (i in sel_pts):
			continue
		var pt_color := SKELLY_SELECTED_POINT_COLOR if i in sel_pts else SKELLY_POINT_COLOR
		draw_circle(points[i], pt_r, pt_color)

func _draw_selection_box() -> void:
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return

	var selected_positions: Array[Vector2] = []
	for cmd_idx in EditorState.selected_point_indices:
		var cmd: DrawCommand = frame.commands[cmd_idx]
		if cmd.hidden:
			continue
		for pt_idx in EditorState.selected_point_indices[cmd_idx]:
			if pt_idx < cmd.points.size():
				selected_positions.append(_point_with_drag_offset(cmd.points[pt_idx], cmd_idx, pt_idx))

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

func _draw_drag_selection_box() -> void:
	if not _drag_selection_active:
		return

	var line_w := SKELLY_PATH_WIDTH_PX / EditorState.current_zoom
	draw_rect(_drag_selection_rect, DRAG_SELECTION_BOX_COLOR, false, line_w)

func get_point_at(world_pos: Vector2) -> Array:
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return []
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

func get_points_in_rect(rect: Rect2) -> Array:
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return []
	var selected: Array = []
	for cmd_idx in range(frame.commands.size()):
		var cmd: DrawCommand = frame.commands[cmd_idx]
		if cmd.hidden:
			continue
		for pt_idx in range(cmd.points.size()):
			if rect.has_point(_point_with_drag_offset(cmd.points[pt_idx], cmd_idx, pt_idx)):
				selected.append([cmd_idx, pt_idx])
	return selected

func get_best_point_in_rect(rect: Rect2, world_pos: Vector2) -> Array:
	var hits: Array = get_points_in_rect(rect)
	if hits.is_empty():
		return []

	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return []

	var best_hit: Array = hits[0]
	var best_dist := world_pos.distance_squared_to(
		_point_with_drag_offset(frame.commands[best_hit[0]].points[best_hit[1]], best_hit[0], best_hit[1])
	)
	for i in range(1, hits.size()):
		var hit: Array = hits[i]
		var dist := world_pos.distance_squared_to(
			_point_with_drag_offset(frame.commands[hit[0]].points[hit[1]], hit[0], hit[1])
		)
		if dist < best_dist:
			best_dist = dist
			best_hit = hit
	return best_hit

func set_drag_selection_rect(rect: Rect2, active: bool) -> void:
	_drag_selection_rect = rect
	_drag_selection_active = active
	queue_redraw()

func _draw_circle_skeleton(cmd: DrawCommand, cmd_idx: int, sel_pts: Array, line_w: float, pt_r: float, show_only_selected: bool) -> void:
	if cmd.points.is_empty():
		return

	var center := _point_with_drag_offset(cmd.points[0], cmd_idx, 0)
	var is_selected := 0 in sel_pts
	if show_only_selected and not is_selected:
		return
	var outline_color := SKELLY_SELECTED_PATH_COLOR if is_selected else SKELLY_PATH_COLOR
	var pt_color := SKELLY_SELECTED_POINT_COLOR if is_selected else SKELLY_POINT_COLOR

	draw_arc(center, float(cmd.circle_radius), 0.0, TAU, 64, outline_color, line_w)
	draw_circle(center, pt_r, pt_color)

func _point_with_drag_offset(point: Vector2, cmd_idx: int, pt_idx: int) -> Vector2:
	if not EditorState.is_dragging_selection or EditorState.drag_offset == Vector2.ZERO:
		return point
	var selected_pts: Array = EditorState.selected_point_indices.get(cmd_idx, [])
	if pt_idx in selected_pts:
		return point + EditorState.drag_offset
	return point

func _points_with_drag_offset(points: PackedVector2Array, cmd_idx: int) -> PackedVector2Array:
	if not EditorState.is_dragging_selection or EditorState.drag_offset == Vector2.ZERO:
		return points
	var selected_pts: Array = EditorState.selected_point_indices.get(cmd_idx, [])
	if selected_pts.is_empty():
		return points
	var shifted: PackedVector2Array = points.duplicate()
	for pt_idx in selected_pts:
		if pt_idx >= 0 and pt_idx < shifted.size():
			shifted[pt_idx] += EditorState.drag_offset
	return shifted
