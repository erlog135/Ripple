extends Node

signal canvas_area_rect_changed(rect: Rect2)
signal tool_changed(tool: Tool)
signal selection_changed(by_user: bool)
signal options_changed

signal mouse_position_changed(screen_pos: Vector2)
signal zoom_changed(screen_pos: Vector2, zoom_factor: float)
signal pan_changed(screen_offset: Vector2)
signal drag_updated(offset: Vector2, dragging: bool)

signal current_frame_changed(frame: int)
signal line_pen_hover_changed()

const ZOOM_STEP := 0.1
const MIN_ZOOM  := 0.2
const MAX_ZOOM  := 80.0

enum Tool {
	SELECT,
	MOVE,
	LINE_PEN,
	CIRCLE,
	RECTANGLE,
	PAN
}

var active_tool: Tool = Tool.SELECT
var current_frame: int = 0
var current_zoom: float = 1.0
var current_pan: Vector2 = Vector2.ZERO
var current_camera_pos: Vector2 = Vector2.ZERO
var drag_offset: Vector2 = Vector2.ZERO
var is_dragging_selection: bool = false

var selected_command_indices: Array[int] = []
var selected_point_indices: Dictionary[int, Array] = {}

## Mirrors Fill & Stroke UI; used when creating new geometry (e.g. Line Pen).
var current_fill_color: Color = Color.BLACK
var current_stroke_color: Color = Color.BLACK
var current_stroke_width: int = 1

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


func change_tool(tool: Tool) -> void:
	active_tool = tool
	tool_changed.emit(tool)

func zoom_in(screen_pos: Vector2) -> void:
	var factor := 1.0 + ZOOM_STEP
	current_zoom = clamp(current_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	zoom_changed.emit(screen_pos, factor)

func zoom_out(screen_pos: Vector2) -> void:
	var factor := 1.0 - ZOOM_STEP
	current_zoom = clamp(current_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	zoom_changed.emit(screen_pos, factor)

func pan(screen_offset: Vector2) -> void:
	current_pan += screen_offset
	pan_changed.emit(screen_offset)

func update_canvas_area_rect(rect: Rect2) -> void:
	canvas_area_rect_changed.emit(rect)

func update_mouse_position(screen_pos: Vector2) -> void:
	mouse_position_changed.emit(screen_pos)

func update_drag(offset: Vector2, dragging: bool) -> void:
	drag_offset = offset
	is_dragging_selection = dragging
	drag_updated.emit(drag_offset, is_dragging_selection)

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
