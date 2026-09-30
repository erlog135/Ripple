extends Control

const EditTool = preload("res://scenes/interface/aux_windows/tools/edit_tool.gd")
const PenToolScr = preload("res://scenes/interface/aux_windows/tools/line_pen_tool.gd")
const CircleToolScr = preload("res://scenes/interface/aux_windows/tools/circle_tool.gd")
const RectangleToolScr = preload("res://scenes/interface/aux_windows/tools/rectangle_tool.gd")

@onready var _gizmos = $"../DocumentLayer/SubViewport/DocumentGizmos"

var _tools: Dictionary = {}


func _ready() -> void:
	_tools[EditorState.Tool.EDIT] = EditTool.new()
	_tools[EditorState.Tool.LINE_PEN] = PenToolScr.new()
	_tools[EditorState.Tool.CIRCLE] = CircleToolScr.new()
	_tools[EditorState.Tool.RECTANGLE] = RectangleToolScr.new()

	EditorState.set_canvas_viewport_size(get_rect().size)
	EditorState.tool_changed.connect(_on_tool_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		EditorState.set_canvas_viewport_size(get_rect().size)


func _get_active_tool() -> BaseTool:
	return _tools.get(EditorState.active_tool, null)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		EditorState.update_mouse_position(event.position)
		var tool := _get_active_tool()
		if tool != null:
			tool.handle_mouse_motion(_screen_to_world(event.position), _gizmos)
			mouse_default_cursor_shape = tool.get_cursor_shape()

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if EditorState.active_tool == EditorState.Tool.PAN:
			EditorState.pan(-event.relative)

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		EditorState.pan(-event.relative)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		EditorState.zoom_in(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		EditorState.zoom_out(event.position)

	if event is InputEventMagnifyGesture:
		EditorState.zoom_by_factor(event.position, event.factor)
	elif event is InputEventPanGesture:
		EditorState.pan(event.delta)

	if event is InputEventMouseButton and event.pressed:
		# Release focus from any SpinBox/LineEdit so canvas shortcuts work immediately.
		get_viewport().gui_release_focus()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var tool := _get_active_tool()
		if tool != null:
			var world_pos := _screen_to_world(event.position)
			var additive := Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL)

			if event.pressed:
				if event.double_click and tool.handle_double_click(world_pos, additive, _gizmos):
					accept_event()
					return
				tool.handle_left_press(world_pos, additive, _gizmos)
			else:
				tool.handle_left_release(world_pos, _gizmos)

			mouse_default_cursor_shape = tool.get_cursor_shape()


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var canvas_center := get_rect().size / 2.0
	return EditorState.current_camera_pos + (screen_pos - canvas_center) / EditorState.current_zoom


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			_delete_selected_points()
		if event.keycode == KEY_ESCAPE:
			EditorState.deselect_all()
			EditorState.change_tool(EditorState.Tool.EDIT)


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
	for t: BaseTool in _tools.values():
		t.cancel(_gizmos)
	var active := _get_active_tool()
	mouse_default_cursor_shape = active.get_cursor_shape() if active != null else Control.CURSOR_ARROW
