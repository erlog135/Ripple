extends Control


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if EditorState.active_tool == EditorState.Tool.PAN:
			EditorState.pan(-event.relative)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		EditorState.zoom_in(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		EditorState.zoom_out(event.position)
			
