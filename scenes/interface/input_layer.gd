extends Control

@onready var _gizmos: Node2D = $"../DocumentLayer/SubViewport/DocumentGizmos"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		EditorState.update_mouse_position(event.position)

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if EditorState.active_tool == EditorState.Tool.PAN:
			EditorState.pan(-event.relative)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		EditorState.zoom_in(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		EditorState.zoom_out(event.position)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if EditorState.active_tool == EditorState.Tool.SELECT:
			var world_pos := _screen_to_world(event.position)
			var hit: Array = _gizmos.get_point_at(world_pos)
			if hit.is_empty():
				if not Input.is_key_pressed(KEY_SHIFT):
					EditorState.deselect_all()
			else:
				EditorState.select_point(hit[0], hit[1], Input.is_key_pressed(KEY_SHIFT))


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var canvas_center := get_rect().size / 2.0
	return EditorState.current_camera_pos + (screen_pos - canvas_center) / EditorState.current_zoom
			
