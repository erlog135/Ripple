extends Node2D

const GRID_COLOR := Color(0.5, 0.5, 0.5, 0.75)
const DOCUMENT_OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.5)
const SKELLY_POINT_COLOR := GColor.WHITE
const SKELLY_SELECTED_POINT_COLOR := GColor.VERY_LIGHT_BLUE
const SKELLY_PATH_COLOR := Color(0.5, 0.5, 0.5, 1.0)
const SKELLY_SELECTED_PATH_COLOR := GColor.VERY_LIGHT_BLUE

## Highlight color used when a segment's angle matches one of the permitted pixel-art angles.
const ANGLE_VALID_COLOR := Color(0.15, 0.85, 0.35, 0.92)
## Tolerance in radians (~0.5°) used when comparing a segment angle to a permitted angle.
const ANGLE_TOLERANCE_RAD := 0.009

const SKELLY_POINT_RADIUS_PX := 4.0
const SKELLY_PATH_WIDTH_PX := 2.0
const TRANSFORM_HANDLE_PX := 4.0
const SELECTION_BOX_COLOR := Color(0.4, 0.7, 1.0, 0.85)
const DRAG_SELECTION_BOX_COLOR := Color(0.4, 0.7, 1.0, 0.45)
const LINE_PEN_PREVIEW_COLOR := Color(0.0, 0.5, 1.0, 0.8)
const PenToolScr = preload("res://scenes/interface/aux_windows/tools/line_pen_tool.gd")

var _drag_selection_rect := Rect2()
var _drag_selection_active := false
var _cursor_world_pos := Vector2.ZERO


func _ready() -> void:
	ProjectData.data_changed.connect(_on_data_changed)
	EditorState.current_frame_changed.connect(_on_current_frame_changed)
	EditorState.zoom_changed.connect(_on_zoom_changed)
	EditorState.view_changed.connect(_on_view_changed)
	EditorState.pan_changed.connect(_on_pan_changed)
	EditorState.playback_state_changed.connect(_on_playback_state_changed)
	EditorState.selection_changed.connect(_on_selection_changed)
	EditorState.tool_changed.connect(_on_tool_changed)
	EditorState.transform_preview_changed.connect(_on_transform_preview_changed)
	EditorState.line_pen_hover_changed.connect(_on_line_pen_hover_changed)
	EditorState.validate_line_angles_changed.connect(_on_validate_line_angles_changed)
	EditorState.shape_preview_changed.connect(_on_shape_preview_changed)
	EditorState.mouse_position_changed.connect(_on_mouse_position_changed)

func _on_data_changed(_by_user: bool, _affected_frame: int) -> void:
	queue_redraw()


func _on_current_frame_changed(_frame: int) -> void:
	queue_redraw()


func _on_zoom_changed(_screen_pos: Vector2, _factor: float) -> void:
	queue_redraw()


func _on_view_changed() -> void:
	queue_redraw()

func _on_pan_changed(_screen_offset: Vector2) -> void:
	queue_redraw()

func _on_playback_state_changed(_playing: bool) -> void:
	queue_redraw()

func _on_selection_changed(_by_user: bool) -> void:
	queue_redraw()

func _on_tool_changed(_tool: EditorState.Tool) -> void:
	queue_redraw()

func _on_transform_preview_changed() -> void:
	queue_redraw()

func _on_line_pen_hover_changed() -> void:
	queue_redraw()

func _on_validate_line_angles_changed(_enabled: bool) -> void:
	queue_redraw()

func _on_shape_preview_changed() -> void:
	queue_redraw()

func _on_mouse_position_changed(screen_pos: Vector2) -> void:
	var canvas_center := get_viewport().get_visible_rect().size / 2.0
	_cursor_world_pos = EditorState.current_camera_pos + (screen_pos - canvas_center) / EditorState.current_zoom
	if EditorState.current_zoom >= 40.0:
		queue_redraw()

func _draw() -> void:
	if EditorState.is_playing:
		return
	_draw_shape_preview()
	_draw_shape_tool_gizmo()
	if EditorState.current_zoom >= 10.0:
		_draw_pixel_grid()
	_draw_document_bounds()
	_draw_skeletons()
	_draw_angle_validation()
	_draw_line_pen_preview()
	_draw_drag_selection_box()
	_draw_selection_box()
	_draw_cursor_coords()

func _draw_pixel_grid() -> void:
	var vp_rect := get_viewport().get_visible_rect()
	var inv := get_canvas_transform().affine_inverse()
	var tl := inv * vp_rect.position
	var br := inv * (vp_rect.position + vp_rect.size)

	var x_start := floori(tl.x)
	var x_end := ceili(br.x)
	var y_start := floori(tl.y)
	var y_end := ceili(br.y)
	var line_w := 1.0 / EditorState.current_zoom

	for x in range(x_start, x_end + 1):
		draw_line(Vector2(x, y_start), Vector2(x, y_end), GRID_COLOR, line_w)

	for y in range(y_start, y_end + 1):
		draw_line(Vector2(x_start, y), Vector2(x_end, y), GRID_COLOR, line_w)


func _draw_document_bounds() -> void:
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return
	var bounds: Vector2i = frame.bounds
	if bounds.x <= 0 or bounds.y <= 0:
		return
	var line_w := 1.0 / EditorState.current_zoom
	draw_rect(Rect2(Vector2.ZERO, Vector2(bounds)), DOCUMENT_OUTLINE_COLOR, false, line_w)

func _draw_skeletons() -> void:
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return

	var line_w := SKELLY_PATH_WIDTH_PX / EditorState.current_zoom
	var pt_r := SKELLY_POINT_RADIUS_PX / EditorState.current_zoom
	var show_only_selected := EditorState.active_tool != EditorState.Tool.EDIT
	# For EDIT and LINE_PEN, show all points/segments within a command
	# (non-selected ones render in the dimmed white/gray palette to provide context).
	var show_full_cmd := (
		EditorState.active_tool == EditorState.Tool.EDIT
		or EditorState.active_tool == EditorState.Tool.LINE_PEN
	)

	for cmd_idx in range(frame.commands.size()):
		var cmd: DrawCommand = frame.commands[cmd_idx]
		if cmd.hidden:
			continue
		var sel_pts: Array = EditorState.selected_point_indices.get(cmd_idx, [])
		if show_only_selected and sel_pts.is_empty():
			continue
		var effective_show_only := show_only_selected and not show_full_cmd
		match cmd.draw_type:
			DrawCommand.Type.PATH, DrawCommand.Type.PRECISE_PATH:
				_draw_path_skeleton(cmd, cmd_idx, sel_pts, line_w, pt_r, effective_show_only)
			DrawCommand.Type.CIRCLE:
				_draw_circle_skeleton(cmd, cmd_idx, sel_pts, line_w, pt_r, effective_show_only)


func _draw_line_pen_preview() -> void:
	if EditorState.active_tool != EditorState.Tool.LINE_PEN:
		return
	var hover: Vector2 = EditorState.line_pen_hover_world
	var line_w := SKELLY_PATH_WIDTH_PX / EditorState.current_zoom
	var pt_r := SKELLY_POINT_RADIUS_PX / EditorState.current_zoom

	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame != null:
		var ctx: Dictionary = PenToolScr.line_pen_rubber_band_context(frame)
		if not ctx.is_empty():
			var cmd_idx: int = ctx[&"cmd_idx"]
			if cmd_idx >= 0 and cmd_idx < frame.commands.size():
				var cmd: DrawCommand = frame.commands[cmd_idx]
				var pts: Array = ctx[&"pts"]
				if pts.size() == 1:
					var pi: int = int(pts[0])
					if pi >= 0 and pi < cmd.points.size():
						var a := _point_with_drag_offset(cmd.points[pi], cmd_idx, pi)
						draw_line(a, hover, LINE_PEN_PREVIEW_COLOR, line_w)
						if EditorState.validate_line_angles and _is_segment_angle_valid(a, hover):
							draw_line(a, hover, ANGLE_VALID_COLOR, line_w)
				elif pts.size() == 2:
					var ia: int = int(pts[0])
					var ib: int = int(pts[1])
					if ia >= 0 and ia < cmd.points.size() and ib >= 0 and ib < cmd.points.size():
						var pa := _point_with_drag_offset(cmd.points[ia], cmd_idx, ia)
						var pb := _point_with_drag_offset(cmd.points[ib], cmd_idx, ib)
						draw_line(pa, hover, LINE_PEN_PREVIEW_COLOR, line_w)
						draw_line(hover, pb, LINE_PEN_PREVIEW_COLOR, line_w)
						if EditorState.validate_line_angles:
							if _is_segment_angle_valid(pa, hover):
								draw_line(pa, hover, ANGLE_VALID_COLOR, line_w)
							if _is_segment_angle_valid(hover, pb):
								draw_line(hover, pb, ANGLE_VALID_COLOR, line_w)

	# Preview dot shows where the next placed point will land.
	# Visible even when starting a brand-new command (ctx is empty).
	draw_circle(hover, pt_r, LINE_PEN_PREVIEW_COLOR)


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
				var p := _point_with_drag_offset(cmd.points[pt_idx], cmd_idx, pt_idx)
				selected_positions.append(p)
				# For circles, also push the four cardinal arc extents so the
				# bounding box has area and the scale handles appear.
				if cmd.draw_type == DrawCommand.Type.CIRCLE and pt_idx == 0:
					var r := float(cmd.circle_radius)
					selected_positions.append(p + Vector2(r, 0.0))
					selected_positions.append(p - Vector2(r, 0.0))
					selected_positions.append(p + Vector2(0.0, r))
					selected_positions.append(p - Vector2(0.0, r))

	if selected_positions.size() < 2:
		return

	var min_pos := selected_positions[0]
	var max_pos := selected_positions[0]
	for pos in selected_positions:
		min_pos = min_pos.min(pos)
		max_pos = max_pos.max(pos)

	var line_w := SKELLY_PATH_WIDTH_PX / EditorState.current_zoom
	var rect := Rect2(min_pos, max_pos - min_pos)
	draw_rect(rect, SELECTION_BOX_COLOR, false, line_w)

	# Resize handles for the Edit tool (only when idle and the box has width or height).
	if (
		EditorState.active_tool == EditorState.Tool.EDIT
		and not EditorState.is_transform_previewing()
		and (rect.size.x > 0.0001 or rect.size.y > 0.0001)
	):
		_draw_transform_handles(rect, line_w)

func _draw_transform_handles(rect: Rect2, line_w: float) -> void:
	var handle := TRANSFORM_HANDLE_PX / EditorState.current_zoom
	var p := rect.position
	var s := rect.size
	var c := rect.get_center()

	var has_x := s.x > 0.0001
	var has_y := s.y > 0.0001

	var positions: Array[Vector2] = []
	if has_x and has_y:
		positions = [
			p,                            # 0 TL
			Vector2(p.x + s.x, p.y),      # 1 TR
			p + s,                        # 2 BR
			Vector2(p.x, p.y + s.y),      # 3 BL
			Vector2(c.x, p.y),            # 4 TM
			Vector2(c.x, p.y + s.y),      # 5 BM
			Vector2(p.x, c.y),            # 6 LM
			Vector2(p.x + s.x, c.y),      # 7 RM
		]
	elif has_x:
		positions = [
			Vector2(p.x, c.y),            # 6 LM
			Vector2(p.x + s.x, c.y),      # 7 RM
		]
	elif has_y:
		positions = [
			Vector2(c.x, p.y),            # 4 TM
			Vector2(c.x, p.y + s.y),      # 5 BM
		]
	else:
		return

	for hp in positions:
		var hr := Rect2(hp - Vector2(handle, handle), Vector2(handle, handle) * 2.0)
		draw_rect(hr, GColor.WHITE, true)
		draw_rect(hr, SELECTION_BOX_COLOR, false, line_w)

func _draw_drag_selection_box() -> void:
	if not _drag_selection_active:
		return

	var line_w := SKELLY_PATH_WIDTH_PX / EditorState.current_zoom
	draw_rect(_drag_selection_rect, DRAG_SELECTION_BOX_COLOR, false, line_w)

func _draw_cursor_coords() -> void:
	if EditorState.current_zoom < 40.0:
		return

	var pos := _cursor_world_pos
	var zoom := EditorState.current_zoom

	# Dot at the exact coordinate (translucent white).
	var dot_r := 2.0 / zoom
	draw_circle(pos.floor(), dot_r, Color(1.0, 1.0, 1.0, 0.5))

	# Text label offset to the bottom-right of the cursor.
	var label := "%d, %d" % [floori(pos.x), floori(pos.y)]
	var font := ThemeDB.fallback_font
	var font_size := 14
	var px_per_unit := 1.0 / zoom

	draw_set_transform(pos.floor(), 0.0, Vector2(px_per_unit, px_per_unit))
	draw_string_outline(font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, Color(0.0, 0.0, 0.0, 0.9))
	draw_string(font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, 1.0))
	draw_set_transform(Vector2.ZERO)

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

## Returns [cmd_idx, pt_idx_a, pt_idx_b] for the nearest PATH/PRECISE_PATH segment
## within tolerance_px screen pixels of world_pos, or [] if none qualifies.
## Segment connectivity mirrors _draw_path_skeleton: consecutive pairs plus the
## closing edge (n-1, 0) when path_open is false and n > 2.
func get_segment_at(world_pos: Vector2, tolerance_px: float) -> Array:
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return []
	var tol := tolerance_px / EditorState.current_zoom
	var best_dist := tol
	var best: Array = []
	for cmd_idx in range(frame.commands.size()):
		var cmd: DrawCommand = frame.commands[cmd_idx]
		if cmd.hidden:
			continue
		if cmd.draw_type == DrawCommand.Type.CIRCLE:
			# Hit-test the arc: measure how close the cursor is to the circle edge.
			if not cmd.points.is_empty():
				var center := _point_with_drag_offset(cmd.points[0], cmd_idx, 0)
				var dist := absf(world_pos.distance_to(center) - float(cmd.circle_radius))
				if dist < best_dist:
					best_dist = dist
					best = [cmd_idx, 0, 0]
			continue
		if cmd.draw_type != DrawCommand.Type.PATH and cmd.draw_type != DrawCommand.Type.PRECISE_PATH:
			continue

		var n := cmd.points.size()
		if n < 2:
			continue
		for i in range(n - 1):
			var a := _point_with_drag_offset(cmd.points[i], cmd_idx, i)
			var b := _point_with_drag_offset(cmd.points[i + 1], cmd_idx, i + 1)
			var closest := Geometry2D.get_closest_point_to_segment(world_pos, a, b)
			var dist := world_pos.distance_to(closest)
			if dist < best_dist:
				best_dist = dist
				best = [cmd_idx, i, i + 1]
		if not cmd.path_open and n > 2:
			var a := _point_with_drag_offset(cmd.points[n - 1], cmd_idx, n - 1)
			var b := _point_with_drag_offset(cmd.points[0], cmd_idx, 0)
			var closest := Geometry2D.get_closest_point_to_segment(world_pos, a, b)
			var dist := world_pos.distance_to(closest)
			if dist < best_dist:
				best_dist = dist
				best = [cmd_idx, n - 1, 0]
	return best


func set_drag_selection_rect(rect: Rect2, active: bool) -> void:
	_drag_selection_rect = rect
	_drag_selection_active = active
	queue_redraw()

## Overlays green segments on PATH/PRECISE_PATH commands, using the exact same
## visibility rules as _draw_skeletons so the green only appears where a skeleton
## line is already drawn.
func _draw_angle_validation() -> void:
	if not EditorState.validate_line_angles:
		return
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return
	var line_w := SKELLY_PATH_WIDTH_PX / EditorState.current_zoom
	var show_only_selected := EditorState.active_tool != EditorState.Tool.EDIT
	var show_full_cmd := (
		EditorState.active_tool == EditorState.Tool.EDIT
		or EditorState.active_tool == EditorState.Tool.LINE_PEN
	)
	for cmd_idx in range(frame.commands.size()):
		var cmd: DrawCommand = frame.commands[cmd_idx]
		if cmd.hidden:
			continue
		var sel_pts: Array = EditorState.selected_point_indices.get(cmd_idx, [])
		if show_only_selected and sel_pts.is_empty():
			continue
		var effective_show_only := show_only_selected and not show_full_cmd
		match cmd.draw_type:
			DrawCommand.Type.PATH, DrawCommand.Type.PRECISE_PATH:
				_draw_path_angle_validation(cmd, cmd_idx, sel_pts, line_w, effective_show_only)


func _draw_path_angle_validation(cmd: DrawCommand, cmd_idx: int, sel_pts: Array, line_w: float, show_only_selected: bool) -> void:
	var points := _points_with_drag_offset(cmd.points, cmd_idx)
	var n := points.size()
	if n < 2:
		return
	for i in range(n - 1):
		var seg_selected := (i in sel_pts) and ((i + 1) in sel_pts)
		if show_only_selected and not seg_selected:
			continue
		if _is_segment_angle_valid(points[i], points[i + 1]):
			draw_line(points[i], points[i + 1], ANGLE_VALID_COLOR, line_w)
	if not cmd.path_open and n > 2:
		var seg_selected := ((n - 1) in sel_pts) and (0 in sel_pts)
		if not show_only_selected or seg_selected:
			if _is_segment_angle_valid(points[n - 1], points[0]):
				draw_line(points[n - 1], points[0], ANGLE_VALID_COLOR, line_w)


## Returns true when the line from [param a] to [param b] matches one of the
## pixel-art permitted angles (horizontal, 3:1, 2:1, 1:1, 1:2, 1:3, vertical,
## and all their 180° mirrors). Degenerate zero-length segments are considered valid.
##
## Method: atan2 angle is normalised to [0, PI) then folded into [0, PI/2] by
## reflecting around PI/2, so only the 7 canonical half-angles need checking.
func _is_segment_angle_valid(a: Vector2, b: Vector2) -> bool:
	var delta := b - a
	if delta.length_squared() < 0.0001:
		return true
	var angle := atan2(delta.y, delta.x)
	# Normalise directed angle to the undirected range [0, PI).
	angle = fmod(angle, PI)
	if angle < 0.0:
		angle += PI
	# Fold to [0, PI/2] — symmetric pairs (e.g. 135° ↔ 45°) share the same half-angle.
	var half_angle := minf(angle, PI - angle)
	# Canonical half-angles for the seven permitted directions:
	#   0°  (horizontal)   atan(0)   = 0
	#   3:1 (18.43°)       atan(1/3) ≈ 0.32175
	#   2:1 (26.57°)       atan(1/2) ≈ 0.46365
	#   1:1 (45°)          PI/4      ≈ 0.78540
	#   1:2 (63.43°)       atan(2)   ≈ 1.10715
	#   1:3 (71.57°)       atan(3)   ≈ 1.24905
	#   90° (vertical)     PI/2      ≈ 1.57080
	const PERMITTED: Array[float] = [
		0.0,
		0.32175055439664219,
		0.46364760900080611,
		0.78539816339744831, # PI / 4
		1.10714871779409040,
		1.24904577239825420,
		1.57079632679489662, # PI / 2
	]
	for permitted: float in PERMITTED:
		if absf(half_angle - permitted) < ANGLE_TOLERANCE_RAD:
			return true
	return false


func _draw_circle_skeleton(cmd: DrawCommand, cmd_idx: int, sel_pts: Array, line_w: float, pt_r: float, show_only_selected: bool) -> void:
	if cmd.points.is_empty():
		return

	var center := _point_with_drag_offset(cmd.points[0], cmd_idx, 0)
	var is_selected := 0 in sel_pts
	if show_only_selected and not is_selected:
		return
	var outline_color := SKELLY_SELECTED_PATH_COLOR if is_selected else SKELLY_PATH_COLOR
	var pt_color := SKELLY_SELECTED_POINT_COLOR if is_selected else SKELLY_POINT_COLOR

	# During a scale preview, show the radius scaled by the current transform matrix
	# so the arc visually matches what will be committed on release.
	var display_radius := float(cmd.circle_radius)
	if is_selected and EditorState.is_transform_previewing() and EditorState.transform_mode == EditorState.TransformMode.SCALE:
		var m := EditorState.transform_matrix
		var radius_scale := (m.x.length() + m.y.length()) / 2.0
		display_radius = maxf(1.0, display_radius * radius_scale)

	draw_arc(center, display_radius, 0.0, TAU, 64, outline_color, line_w)
	draw_circle(center, pt_r, pt_color)

func _point_with_drag_offset(point: Vector2, cmd_idx: int, pt_idx: int) -> Vector2:
	if not EditorState.is_transform_previewing():
		return point
	var selected_pts: Array = EditorState.selected_point_indices.get(cmd_idx, [])
	if pt_idx in selected_pts:
		var transformed := EditorState.transform_matrix * point
		if EditorState.grid_snap:
			var frame: DrawCommandImage = ProjectData.get_current_image()
			if frame != null and cmd_idx < frame.commands.size():
				var cmd: DrawCommand = frame.commands[cmd_idx]
				transformed = EditorState.snap_world_position(
					transformed, cmd.draw_type, cmd.stroke_width
				)
		return transformed
	return point

func _points_with_drag_offset(points: PackedVector2Array, cmd_idx: int) -> PackedVector2Array:
	if not EditorState.is_transform_previewing():
		return points
	var selected_pts: Array = EditorState.selected_point_indices.get(cmd_idx, [])
	if selected_pts.is_empty():
		return points
	var frame: DrawCommandImage = ProjectData.get_current_image() if EditorState.grid_snap else null
	var cmd: DrawCommand = frame.commands[cmd_idx] if (frame != null and cmd_idx < frame.commands.size()) else null
	var shifted: PackedVector2Array = points.duplicate()
	for pt_idx in selected_pts:
		if pt_idx >= 0 and pt_idx < shifted.size():
			var transformed := EditorState.transform_matrix * shifted[pt_idx]
			if cmd != null:
				transformed = EditorState.snap_world_position(
					transformed, cmd.draw_type, cmd.stroke_width
				)
			shifted[pt_idx] = transformed
	return shifted


## Draws a skeleton-style wireframe overlay (blue lines + point dots) on top of
## the shape-preview fill/stroke, giving visual feedback consistent with the edit
## tool's gizmo while the circle or rectangle drawing tool is actively dragging.
func _draw_shape_tool_gizmo() -> void:
	if not EditorState.shape_preview_active:
		return

	var line_w := SKELLY_PATH_WIDTH_PX / EditorState.current_zoom
	var pt_r := SKELLY_POINT_RADIUS_PX / EditorState.current_zoom

	if EditorState.shape_preview_type == EditorState.Tool.CIRCLE:
		var center := EditorState.shape_preview_circle_center
		var radius := EditorState.shape_preview_circle_radius
		if radius < 0.0001:
			return
		draw_arc(center, radius, 0.0, TAU, 64, SKELLY_SELECTED_PATH_COLOR, line_w)
		draw_circle(center, pt_r, SKELLY_SELECTED_POINT_COLOR)

	elif EditorState.shape_preview_type == EditorState.Tool.RECTANGLE:
		var points := EditorState.shape_preview_rect_points
		if points.size() < 4:
			return
		# Draw the four edges as a closed polyline.
		var closed := PackedVector2Array(points)
		closed.append(points[0])
		draw_polyline(closed, SKELLY_SELECTED_PATH_COLOR, line_w)
		# Draw a dot at each corner.
		for pt in points:
			draw_circle(pt, pt_r, SKELLY_SELECTED_POINT_COLOR)

func _draw_shape_preview() -> void:
	if not EditorState.shape_preview_active:
		return


	var fill_color := EditorState.current_fill_color
	var stroke_color := EditorState.current_stroke_color

	var stroke_width := float(EditorState.current_stroke_width)

	if EditorState.shape_preview_type == EditorState.Tool.CIRCLE:
		var center := EditorState.shape_preview_circle_center
		var radius := EditorState.shape_preview_circle_radius
		if radius < 0.0001:
			return

		# Draw Fill
		if fill_color.a > 0.0:
			draw_circle(center, radius, fill_color)

		# Draw Stroke
		if stroke_color.a > 0.0 and stroke_width > 0.0:
			draw_arc(center, radius, 0.0, TAU, 64, stroke_color, stroke_width)

	elif EditorState.shape_preview_type == EditorState.Tool.RECTANGLE:
		var points := EditorState.shape_preview_rect_points
		if points.size() < 4:
			return

		# Draw Fill
		if fill_color.a > 0.0:
			draw_colored_polygon(points, fill_color)

		# Draw Stroke
		if stroke_color.a > 0.0 and stroke_width > 0.0:
			var closed_points := points.duplicate()
			closed_points.append(points[0])
			draw_polyline(closed_points, stroke_color, stroke_width)
