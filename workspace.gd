extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var pdc_visualizer: PDCVisualizer = $PDCVisualizer

var _is_panning := false

func _unhandled_input(event: InputEvent) -> void:
	# --- 1. Toggle Pixelation ---
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		pdc_visualizer.pixelated = !pdc_visualizer.pixelated

	# --- 2. Panning ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed

	elif event is InputEventMouseMotion and _is_panning:
		camera.position -= event.relative / camera.zoom
