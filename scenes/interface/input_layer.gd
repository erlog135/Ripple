extends Control

const SelectionTool = preload("res://scenes/interface/aux_windows/tools/selection_tool.gd")
const TransformTool = preload("res://scenes/interface/aux_windows/tools/transform_tool.gd")
const PenToolScr = preload("res://scenes/interface/aux_windows/tools/line_pen_tool.gd")

@onready var _gizmos = $"../DocumentLayer/SubViewport/DocumentGizmos"
@onready var _selection_tool = SelectionTool.new()
@onready var _transform_tool = TransformTool.new()
@onready var _line_pen_tool: RefCounted = PenToolScr.new()


func _ready() -> void:
	EditorState.set_canvas_viewport_size(get_rect().size)
	EditorState.tool_changed.connect(_on_tool_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		EditorState.set_canvas_viewport_size(get_rect().size)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		EditorState.update_mouse_position(event.position)
		if EditorState.active_tool == EditorState.Tool.LINE_PEN:
			_line_pen_tool.handle_mouse_motion(_screen_to_world(event.position))
		elif EditorState.active_tool == EditorState.Tool.TRANSFORM:
			# Handles both contextual hover and active drag (the tool branches internally).
			_transform_tool.handle_mouse_motion(_screen_to_world(event.position))
			mouse_default_cursor_shape = _transform_tool.cursor_shape

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if EditorState.active_tool == EditorState.Tool.PAN:
			EditorState.pan(-event.relative)
		elif EditorState.active_tool == EditorState.Tool.SELECT:
			_selection_tool.handle_mouse_motion(_screen_to_world(event.position), _gizmos)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		EditorState.zoom_in(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		EditorState.zoom_out(event.position)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.double_click and _toggle_tool_on_selected_point(_screen_to_world(event.position)):
			accept_event()
			return
		if EditorState.active_tool == EditorState.Tool.SELECT:
			var world_pos := _screen_to_world(event.position)
			if event.pressed:
				_selection_tool.handle_left_press(world_pos, Input.is_key_pressed(KEY_SHIFT))
			else:
				_selection_tool.handle_left_release(world_pos, _gizmos)
		elif EditorState.active_tool == EditorState.Tool.TRANSFORM:
			var world_pos := _screen_to_world(event.position)
			if event.pressed:
				_transform_tool.handle_left_press(world_pos)
			else:
				_transform_tool.handle_left_release(world_pos)
			mouse_default_cursor_shape = _transform_tool.cursor_shape
		elif EditorState.active_tool == EditorState.Tool.LINE_PEN:
			var lp_world_pos := _screen_to_world(event.position)
			if event.pressed:
				_line_pen_tool.handle_left_press(lp_world_pos, _gizmos)
		elif event.pressed:
			_selection_tool.cancel(_gizmos)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var canvas_center := get_rect().size / 2.0
	return EditorState.current_camera_pos + (screen_pos - canvas_center) / EditorState.current_zoom

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE:
			_delete_selected_points()


func _delete_selected_points() -> void:
	if EditorState.selected_point_indices.is_empty():
		return
	var action := DeletePointsAction.new(
		EditorState.current_frame,
		EditorState.selected_point_indices,
		EditorState.selected_command_indices,
		EditorState.selected_point_indices,
	)
	HistoryManager.commit(action)


func _on_tool_changed(_tool: EditorState.Tool) -> void:
	_selection_tool.cancel(_gizmos)
	_transform_tool.cancel()
	mouse_default_cursor_shape = _transform_tool.cursor_shape


## Toggles between Select and Transform when a double-click lands on a selected
## point or anywhere inside the selection bounding box. Returns true when toggled.
## Returns false (no toggle) when the double-click hits an unselected point.
func _toggle_tool_on_selected_point(world_pos: Vector2) -> bool:
	var tool := EditorState.active_tool
	if tool != EditorState.Tool.SELECT and tool != EditorState.Tool.TRANSFORM:
		return false

	var half := Vector2(0.5, 0.5)
	var rect := Rect2(world_pos - half, Vector2.ONE)
	var best_hit: Array = _gizmos.get_best_point_in_rect(rect, world_pos)

	var should_toggle := false
	if best_hit.is_empty():
		if not EditorState.selected_point_indices.is_empty():
			var g := EditorState.get_gizmo_scale()
			should_toggle = EditorState.get_selection_bounds().grow(8.0 * g).has_point(world_pos)
	else:
		var cmd_idx: int = best_hit[0]
		var pt_idx: int = best_hit[1]
		var sel: Dictionary = EditorState.selected_point_indices
		should_toggle = sel.has(cmd_idx) and pt_idx in sel[cmd_idx]

	if not should_toggle:
		return false
	if tool == EditorState.Tool.SELECT:
		EditorState.change_tool(EditorState.Tool.TRANSFORM)
	else:
		EditorState.change_tool(EditorState.Tool.SELECT)
	return true
