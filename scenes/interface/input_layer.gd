extends Control

@onready var document_layer: Control = $"../DocumentLayer"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if EditorState.active_tool == EditorState.Tool.PAN:
			document_layer.set_camera_offset(-event.relative)
	
	if event is InputEventMouseButton and event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_UP:
		document_layer.zoom_in(event.position)
	elif event is InputEventMouseButton and event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_DOWN:
		document_layer.zoom_out(event.position)
			
