extends Node2D

@export var zoom_speed := 0.1
@export var min_zoom := 0.2
@export var max_zoom := 10.0

@onready var camera: Camera2D = $Camera2D
@onready var pdc_visualizer: PDCVisualizer = $PDCVisualizer # Grab a reference to the visualizer

var _is_panning := false

func _unhandled_input(event: InputEvent) -> void:
	# --- 1. Toggle Pixelation ---
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		pdc_visualizer.pixelated = !pdc_visualizer.pixelated # Toggle the property directly

	# --- 2. Panning ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
			
	elif event is InputEventMouseMotion and _is_panning:
		camera.position -= event.relative / camera.zoom

	# --- 3. Zooming ---
	if event is InputEventMouseButton and event.pressed:
		var zoom_factor := 1.0
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_factor = 1.0 + zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_factor = 1.0 - zoom_speed
			
		if zoom_factor != 1.0:
			_zoom_towards_mouse(zoom_factor)

func _zoom_towards_mouse(zoom_factor: float) -> void:
	var previous_zoom := camera.zoom
	var new_zoom_val = clamp(camera.zoom.x * zoom_factor, min_zoom, max_zoom)
	var new_zoom := Vector2(new_zoom_val, new_zoom_val)
	
	var mouse_pos := get_local_mouse_position()
	camera.position += mouse_pos * (Vector2.ONE - (previous_zoom / new_zoom))
	camera.zoom = new_zoom
