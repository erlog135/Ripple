extends Node

signal tool_changed
signal selection_changed
signal options_changed

enum Tool {
	SELECT,
	LINE_PEN,
	CIRCLE,
	RECTANGLE,
	PAN
}

var active_tool: Tool = Tool.PAN
var current_frame: int = 0
