extends Control

const SelectionTool = preload("res://scenes/interface/aux_windows/tools/selection_tool.gd")
const MoveTool = preload("res://scenes/interface/aux_windows/tools/move_tool.gd")

@onready var _gizmos = $"../DocumentLayer/SubViewport/DocumentGizmos"
@onready var _selection_tool = SelectionTool.new()
@onready var _move_tool = MoveTool.new()


func _ready() -> void:
	EditorState.tool_changed.connect(_on_tool_changed)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		EditorState.update_mouse_position(event.position)

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if EditorState.active_tool == EditorState.Tool.PAN:
			EditorState.pan(-event.relative)
		elif EditorState.active_tool == EditorState.Tool.SELECT:
			_selection_tool.handle_mouse_motion(_screen_to_world(event.position), _gizmos)
		elif EditorState.active_tool == EditorState.Tool.MOVE:
			_move_tool.handle_mouse_motion(_screen_to_world(event.position))

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		EditorState.zoom_in(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		EditorState.zoom_out(event.position)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if EditorState.active_tool == EditorState.Tool.SELECT:
			var world_pos := _screen_to_world(event.position)
			if event.pressed:
				_selection_tool.handle_left_press(world_pos, Input.is_key_pressed(KEY_SHIFT))
			else:
				_selection_tool.handle_left_release(world_pos, _gizmos)
		elif EditorState.active_tool == EditorState.Tool.MOVE:
			var world_pos := _screen_to_world(event.position)
			if event.pressed:
				_move_tool.handle_left_press(world_pos)
			else:
				_move_tool.handle_left_release(world_pos)
		elif event.pressed:
			_selection_tool.cancel(_gizmos)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var canvas_center := get_rect().size / 2.0
	return EditorState.current_camera_pos + (screen_pos - canvas_center) / EditorState.current_zoom

func _on_tool_changed(_tool: EditorState.Tool) -> void:
	_selection_tool.cancel(_gizmos)
	_move_tool.cancel()
