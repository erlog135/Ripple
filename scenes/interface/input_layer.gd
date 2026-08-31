extends Control

const EditTool = preload("res://scenes/interface/aux_windows/tools/edit_tool.gd")
const PenToolScr = preload("res://scenes/interface/aux_windows/tools/line_pen_tool.gd")
const CircleToolScr = preload("res://scenes/interface/aux_windows/tools/circle_tool.gd")
const RectangleToolScr = preload("res://scenes/interface/aux_windows/tools/rectangle_tool.gd")

@onready var _gizmos = $"../DocumentLayer/SubViewport/DocumentGizmos"
@onready var _edit_tool = EditTool.new()
@onready var _line_pen_tool: RefCounted = PenToolScr.new()
@onready var _circle_tool = CircleToolScr.new()
@onready var _rectangle_tool = RectangleToolScr.new()


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
		elif EditorState.active_tool == EditorState.Tool.EDIT:
			# Handles hover, active rect-select drag, and active transform drag internally.
			_edit_tool.handle_mouse_motion(_screen_to_world(event.position), _gizmos)
			mouse_default_cursor_shape = _edit_tool.cursor_shape
		elif EditorState.active_tool == EditorState.Tool.CIRCLE:
			_circle_tool.handle_mouse_motion(_screen_to_world(event.position))
		elif EditorState.active_tool == EditorState.Tool.RECTANGLE:
			_rectangle_tool.handle_mouse_motion(_screen_to_world(event.position))

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if EditorState.active_tool == EditorState.Tool.PAN:
			EditorState.pan(-event.relative)

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		EditorState.pan(-event.relative)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		EditorState.zoom_in(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		EditorState.zoom_out(event.position)

	if event is InputEventMouseButton and event.pressed:
		# Release focus from any SpinBox/LineEdit so canvas shortcuts work immediately.
		get_viewport().gui_release_focus()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.double_click:
			if EditorState.active_tool == EditorState.Tool.EDIT:
				var world_pos_dc := _screen_to_world(event.position)
				var additive := Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL)
				_edit_tool.handle_double_click(world_pos_dc, additive, _gizmos)
				accept_event()
				return

		if EditorState.active_tool == EditorState.Tool.EDIT:
			var world_pos := _screen_to_world(event.position)
			if event.pressed:
				var additive := Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL)
				_edit_tool.handle_left_press(world_pos, additive, _gizmos)
			else:
				_edit_tool.handle_left_release(world_pos, _gizmos)
			mouse_default_cursor_shape = _edit_tool.cursor_shape
		elif EditorState.active_tool == EditorState.Tool.LINE_PEN:
			var lp_world_pos := _screen_to_world(event.position)
			if event.pressed:
				_line_pen_tool.handle_left_press(lp_world_pos, _gizmos)
		elif EditorState.active_tool == EditorState.Tool.CIRCLE:
			var world_pos := _screen_to_world(event.position)
			if event.pressed:
				_circle_tool.handle_left_press(world_pos)
			else:
				_circle_tool.handle_left_release(world_pos)
		elif EditorState.active_tool == EditorState.Tool.RECTANGLE:
			var world_pos := _screen_to_world(event.position)
			if event.pressed:
				_rectangle_tool.handle_left_press(world_pos)
			else:
				_rectangle_tool.handle_left_release(world_pos)


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
	_edit_tool.cancel(_gizmos)
	_circle_tool.cancel()
	_rectangle_tool.cancel()
	mouse_default_cursor_shape = _edit_tool.cursor_shape
