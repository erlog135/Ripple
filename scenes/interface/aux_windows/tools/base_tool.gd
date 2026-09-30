class_name BaseTool
extends RefCounted

## Abstract base class defining the contract for all interactive canvas tools.
## Subclasses implement event handling and state management for tools such as
## EditTool, LinePenTool, CircleTool, and RectangleTool.

var cursor_shape: int = Input.CURSOR_ARROW


## Called when mouse moves across the canvas in world coordinates.
func handle_mouse_motion(_world_pos: Vector2, _gizmos = null) -> void:
	pass


## Called when the primary mouse button is pressed.
func handle_left_press(_world_pos: Vector2, _additive: bool = false, _gizmos = null) -> void:
	pass


## Called when the primary mouse button is released.
func handle_left_release(_world_pos: Vector2, _gizmos = null) -> void:
	pass


## Called on primary button double-click. Returns true if the double-click was consumed.
func handle_double_click(_world_pos: Vector2, _additive: bool = false, _gizmos = null) -> bool:
	return false


## Called when the tool is switched away, cancelled via Escape, or interrupted.
func cancel(_gizmos = null) -> void:
	pass


## Returns the desired cursor shape for the tool in its current state.
func get_cursor_shape() -> int:
	return cursor_shape
