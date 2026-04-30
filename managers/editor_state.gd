extends Node

signal canvas_area_rect_changed(rect: Rect2)
signal tool_changed(tool: Tool)
signal selection_changed(by_user: bool)
signal options_changed

signal mouse_position_changed(screen_pos: Vector2)
signal zoom_changed(screen_pos: Vector2, zoom_factor: float)
signal pan_changed(screen_offset: Vector2)

signal current_frame_changed(frame: int)

const ZOOM_STEP := 0.1
const MIN_ZOOM  := 0.2
const MAX_ZOOM  := 50.0

enum Tool {
	SELECT,
	LINE_PEN,
	CIRCLE,
	RECTANGLE,
	PAN
}

var active_tool: Tool = Tool.PAN
var current_frame: int = 0
var current_zoom: float = 1.0
var current_pan: Vector2 = Vector2.ZERO
var current_camera_pos: Vector2 = Vector2.ZERO

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
