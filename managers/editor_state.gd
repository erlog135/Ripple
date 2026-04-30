extends Node

signal tool_changed
signal selection_changed
signal options_changed

signal zoom_changed(screen_pos: Vector2, zoom_factor: float)
signal pan_changed(screen_offset: Vector2)

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

func zoom_in(screen_pos: Vector2) -> void:
	var factor := 1.0 + ZOOM_STEP
	current_zoom = clamp(current_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	zoom_changed.emit(screen_pos, factor)

func zoom_out(screen_pos: Vector2) -> void:
	var factor := 1.0 - ZOOM_STEP
	current_zoom = clamp(current_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	zoom_changed.emit(screen_pos, factor)

func pan(screen_offset: Vector2) -> void:
	pan_changed.emit(screen_offset)
