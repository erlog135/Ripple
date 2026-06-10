extends Node

signal canvas_area_rect_changed(rect: Rect2)
signal tool_changed(tool: Tool)
signal selection_changed(by_user: bool)
signal options_changed
## Emitted when the current fill/stroke/width is changed programmatically (e.g. on
## New Image) so the Fill & Stroke panel can mirror the new values.
signal fill_stroke_changed
signal bg_color_changed

signal mouse_position_changed(screen_pos: Vector2)
signal zoom_changed(screen_pos: Vector2, zoom_factor: float)
signal pan_changed(screen_offset: Vector2)
signal view_changed
signal transform_preview_changed

signal current_frame_changed(frame: int)
signal timeline_zoom_changed
signal line_pen_hover_changed()
signal playback_state_changed(playing: bool)
signal render_mode_changed(mode: RenderMode)
signal clip_to_bounds_changed(enabled: bool)
signal validate_line_angles_changed(enabled: bool)

const ZOOM_STEP := 0.1
const MIN_ZOOM  := 0.2
const MAX_ZOOM  := 80.0

enum Tool {
	SELECT,
	TRANSFORM,
	LINE_PEN,
	CIRCLE,
	RECTANGLE,
	PAN
}

## Sub-mode of the Transform tool, chosen contextually from cursor position + modifiers.
enum TransformMode { NONE, MOVE, SCALE, ROTATE }

enum RenderMode { VECTOR, RASTER }

var active_tool: Tool = Tool.SELECT
var render_mode: RenderMode = RenderMode.VECTOR
var current_frame: int = 0
## Timeline strip horizontal scale (pixels per ms).
var timeline_zoom: float = 1.0
## Multiplier for animator playback (not the canvas zoom).
var playback_speed: float = 1.0
## True while the AnimatorWindow is playing back; gizmo layers should skip drawing while this is set.
var is_playing: bool = false:
	set(value):
		if is_playing == value:
			return
		is_playing = value
		playback_state_changed.emit(is_playing)
var current_zoom: float = 1.0
var current_pan: Vector2 = Vector2.ZERO
var current_camera_pos: Vector2 = Vector2.ZERO
## Size of the canvas input area (used for fit-to-document / fit-to-selection).
var canvas_viewport_size: Vector2 = Vector2.ZERO

## Live preview of the Transform tool. While [member transform_mode] is not NONE,
## [member transform_matrix] is applied to selected points by the renderers/gizmos.
var transform_mode: TransformMode = TransformMode.NONE
var transform_matrix: Transform2D = Transform2D.IDENTITY

var selected_command_indices: Array[int] = []
var selected_point_indices: Dictionary[int, Array] = {}

## Mirrors Fill & Stroke UI; used when creating new geometry (e.g. Line Pen).
var current_fill_color: Color = GColor.WHITE
var current_stroke_color: Color = GColor.BLACK
var current_stroke_width: int = 2
var current_bg_color: Color = GColor.LIGHT_GRAY

## When true, vector/raster preview under this node is clipped to the declared document bounds (Pebble-style clipped preview).
var clip_to_document_bounds: bool = false:
	set(value):
		if clip_to_document_bounds == value:
			return
		clip_to_document_bounds = value
		clip_to_bounds_changed.emit(value)

## When true, line segments are highlighted green in the gizmo overlay when their
## angle matches one of the pixel-art-standard permitted angles.
var validate_line_angles: bool = false:
	set(value):
		if validate_line_angles == value:
			return
		validate_line_angles = value
		validate_line_angles_changed.emit(value)

## When true, point placement snaps to the pixel grid after draw-type rules (whole pixels, or half-pixels when [member grid_odd_snap] applies to odd strokes).
var grid_snap: bool = true
## When [member grid_snap] is true and stroke width is odd, snap to cell centers (…, -0.5, 0.5, 1.5, …). Ignored for even stroke width.
var grid_odd_snap: bool = true

var line_pen_hover_world := Vector2.ZERO


func set_current_fill_color(color: Color) -> void:
	current_fill_color = color


func set_current_stroke_color(color: Color) -> void:
	current_stroke_color = color


func set_current_stroke_width(width: int) -> void:
	current_stroke_width = width


func set_current_fill_stroke(fill: Color, stroke: Color, width: int) -> void:
	current_fill_color = fill
	current_stroke_color = stroke
	current_stroke_width = width
	fill_stroke_changed.emit()

func set_current_bg_color(color: Color):
	if color == current_bg_color:
		return
	current_bg_color = color
	bg_color_changed.emit()

## Single entry point for snapping world-space points (Line Pen, future tools). [param stroke_width] is the stroke that governs odd-grid behavior (layer stroke when editing a layer, [member current_stroke_width] when creating one).
func snap_world_position(world_pos: Vector2, draw_type: DrawCommand.Type, stroke_width: int) -> Vector2:
	var p := world_pos
	if grid_snap:
		if grid_odd_snap and (stroke_width % 2 != 0):
			return (p - Vector2(0.5, 0.5)).snapped(Vector2.ONE) + Vector2(0.5, 0.5)
		return Vector2(roundi(p.x), roundi(p.y))
	if draw_type == DrawCommand.Type.PRECISE_PATH:
		return (p - Vector2(0.5, 0.5)).snapped(Vector2(0.125, 0.125)) + Vector2(0.5, 0.5)
	return Vector2(roundi(p.x), roundi(p.y))


func set_current_frame(frame: int) -> void:
	if ProjectData.current_sequence != null:
		var n: int = ProjectData.current_sequence.frames.size()
		if n > 0:
			frame = clampi(frame, 0, n - 1)
		else:
			frame = 0
	var old_cmd_count := ProjectData.get_current_commands().size()
	var was_all_selected := (old_cmd_count > 0
		and selected_command_indices.size() == old_cmd_count)
	current_frame = frame
	_validate_selection_for_new_frame(was_all_selected)
	current_frame_changed.emit(current_frame)


## Clears all selected commands and points, then emits selection_changed.
func clear_selection() -> void:
	selected_command_indices.clear()
	selected_point_indices.clear()
	selection_changed.emit(false)


## Called whenever current_frame changes. Attempts to keep the existing selection
## valid on the new frame. Out-of-bounds command indices are dropped entirely;
## out-of-bounds point indices are pruned (the shape stays selected). When
## [param was_all_selected] is true, all commands on the new frame are selected
## instead of performing the normal trim. Emits selection_changed once at the end.
func _validate_selection_for_new_frame(was_all_selected: bool = false) -> void:
	if was_all_selected:
		select_all()
		return

	if selected_command_indices.is_empty():
		return

	var commands := ProjectData.get_current_commands()
	var cmd_count := commands.size()

	# Drop any command indices that no longer exist on this frame.
	var valid_cmd_indices: Array[int] = []
	for cmd_idx: int in selected_command_indices:
		if cmd_idx < cmd_count:
			valid_cmd_indices.append(cmd_idx)
	selected_command_indices = valid_cmd_indices

	if selected_command_indices.is_empty():
		selected_point_indices.clear()
		selection_changed.emit(false)
		return

	# Prune the point-selection dictionary: remove entries whose command was
	# dropped, and trim individual point indices that are now out of bounds.
	var stale_keys: Array = []
	for cmd_idx in selected_point_indices.keys():
		if cmd_idx not in selected_command_indices:
			stale_keys.append(cmd_idx)
			continue
		var cmd: DrawCommand = commands[cmd_idx]
		var pts: Array = selected_point_indices[cmd_idx]
		var valid_pts: Array = []
		for pt_idx: int in pts:
			if pt_idx < cmd.points.size():
				valid_pts.append(pt_idx)
		if valid_pts.is_empty():
			stale_keys.append(cmd_idx)
		else:
			selected_point_indices[cmd_idx] = valid_pts
	for key in stale_keys:
		selected_point_indices.erase(key)

	selection_changed.emit(false)


func set_timeline_zoom(zoom: float) -> void:
	timeline_zoom = clampf(zoom, 0.1, 10.0)
	timeline_zoom_changed.emit()


func change_tool(tool: Tool) -> void:
	active_tool = tool
	tool_changed.emit(tool)

func set_render_mode(mode: RenderMode) -> void:
	if render_mode == mode:
		return
	render_mode = mode
	render_mode_changed.emit(render_mode)

func set_canvas_viewport_size(size: Vector2) -> void:
	if canvas_viewport_size == size:
		return
	canvas_viewport_size = size
	update_canvas_area_rect(Rect2(Vector2.ZERO, size))


func _update_view(new_pos: Vector2, new_zoom: float) -> void:
	current_camera_pos = new_pos
	current_zoom = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	view_changed.emit()


func zoom_in(screen_pos: Vector2) -> void:
	var factor := 1.0 + ZOOM_STEP
	current_zoom = clamp(current_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	zoom_changed.emit(screen_pos, factor)


func zoom_out(screen_pos: Vector2) -> void:
	var factor := 1.0 - ZOOM_STEP
	current_zoom = clamp(current_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	zoom_changed.emit(screen_pos, factor)


func zoom_in_centered() -> void:
	_update_view(current_camera_pos, current_zoom * 1.25)


func zoom_out_centered() -> void:
	_update_view(current_camera_pos, current_zoom / 1.25)


func zoom_actual_size() -> void:
	var image := ProjectData.get_current_image()
	var center := Vector2(image.bounds) / 2.0 if image != null else Vector2.ZERO
	_update_view(center, 1.0)


func zoom_to_document(viewport_size: Vector2) -> void:
	var image := ProjectData.get_current_image()
	if image == null or viewport_size == Vector2.ZERO:
		return
	var doc_size := Vector2(image.bounds)
	if doc_size.x <= 0.0 or doc_size.y <= 0.0:
		return
	var padding := 0.9
	var scale_x := viewport_size.x / doc_size.x
	var scale_y := viewport_size.y / doc_size.y
	var fit_scale := minf(scale_x, scale_y) * padding
	_update_view(doc_size / 2.0, fit_scale)


func zoom_to_selection(viewport_size: Vector2) -> void:
	if selected_command_indices.is_empty() or viewport_size == Vector2.ZERO:
		return
	var commands := ProjectData.get_current_commands()
	var selection_rect: Rect2
	for i: int in range(selected_command_indices.size()):
		var idx: int = selected_command_indices[i]
		if idx < 0 or idx >= commands.size():
			continue
		var bounds: Rect2 = commands[idx].get_bounding_box()
		if bounds.size == Vector2.ZERO:
			continue
		if selection_rect.size == Vector2.ZERO:
			selection_rect = bounds
		else:
			selection_rect = selection_rect.merge(bounds)
	if selection_rect.size == Vector2.ZERO:
		return
	selection_rect = selection_rect.grow(5.0)
	var scale_x := viewport_size.x / selection_rect.size.x
	var scale_y := viewport_size.y / selection_rect.size.y
	var fit_scale := minf(scale_x, scale_y)
	_update_view(selection_rect.get_center(), fit_scale)


func fit_document_to_view() -> void:
	if canvas_viewport_size == Vector2.ZERO:
		call_deferred("fit_document_to_view")
		return
	zoom_to_document(canvas_viewport_size)

func pan(screen_offset: Vector2) -> void:
	current_pan += screen_offset
	pan_changed.emit(screen_offset)

func update_canvas_area_rect(rect: Rect2) -> void:
	canvas_area_rect_changed.emit(rect)

func update_mouse_position(screen_pos: Vector2) -> void:
	mouse_position_changed.emit(screen_pos)

func begin_transform(mode: TransformMode) -> void:
	transform_mode = mode
	transform_matrix = Transform2D.IDENTITY
	transform_preview_changed.emit()


func update_transform_matrix(matrix: Transform2D) -> void:
	transform_matrix = matrix
	transform_preview_changed.emit()


func end_transform() -> void:
	transform_mode = TransformMode.NONE
	transform_matrix = Transform2D.IDENTITY
	transform_preview_changed.emit()


## True while a Transform-tool preview is active (a selection is being moved/scaled/rotated).
func is_transform_previewing() -> bool:
	return transform_mode != TransformMode.NONE


## Pixel-to-world scale for sizing gizmo handles consistently regardless of zoom.
func get_gizmo_scale() -> float:
	if current_zoom <= 0.0:
		return 1.0
	return 1.0 / current_zoom


## Bounding box (world space) around all currently selected points. Returns a
## zero-size Rect2 when fewer than one point is selected.
func get_selection_bounds() -> Rect2:
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return Rect2()

	var has_any := false
	var min_pos := Vector2.ZERO
	var max_pos := Vector2.ZERO
	for cmd_idx in selected_point_indices:
		if cmd_idx < 0 or cmd_idx >= frame.commands.size():
			continue
		var cmd: DrawCommand = frame.commands[cmd_idx]
		if cmd.hidden:
			continue
		for pt_idx in selected_point_indices[cmd_idx]:
			if pt_idx < 0 or pt_idx >= cmd.points.size():
				continue
			var p: Vector2 = cmd.points[pt_idx]
			if not has_any:
				min_pos = p
				max_pos = p
				has_any = true
			else:
				min_pos = min_pos.min(p)
				max_pos = max_pos.max(p)

	if not has_any:
		return Rect2()
	return Rect2(min_pos, max_pos - min_pos)

func select_all() -> void:
	selected_command_indices.clear()
	selected_point_indices.clear()

	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return

	for cmd_idx in range(frame.commands.size()):
		var cmd: DrawCommand = frame.commands[cmd_idx]
		selected_command_indices.append(cmd_idx)
		
		var points: Array[int] = []
		for pt_idx in range(cmd.points.size()):
			points.append(pt_idx)
		selected_point_indices.set(cmd_idx, points)
		
	selection_changed.emit(true)

func deselect_all() -> void:
	selected_command_indices.clear()
	selected_point_indices.clear()
	selection_changed.emit(true)


func update_line_pen_hover_world(world_pos: Vector2) -> void:
	if line_pen_hover_world == world_pos:
		return
	line_pen_hover_world = world_pos
	line_pen_hover_changed.emit()


func select_point(cmd_idx: int, pt_idx: int, additive: bool) -> void:
	if not additive:
		selected_command_indices.clear()
		selected_point_indices.clear()

	if cmd_idx not in selected_command_indices:
		selected_command_indices.append(cmd_idx)

	var pts: Array = selected_point_indices.get(cmd_idx, [])
	if pt_idx not in pts:
		pts.append(pt_idx)
	selected_point_indices[cmd_idx] = pts

	selection_changed.emit(true)
