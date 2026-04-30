extends Camera2D


func _ready() -> void:
	EditorState.zoom_changed.connect(_on_zoom_changed)
	EditorState.pan_changed.connect(_on_pan_changed)
	Fileman.pdc_loaded.connect(_on_pdc_loaded)


func _on_pdc_loaded(sequence: DrawCommandSequence) -> void:
	position = Vector2(sequence.frames[0].bounds) / 2.0
	EditorState.current_camera_pos = position


func _on_zoom_changed(screen_pos: Vector2, zoom_factor: float) -> void:
	var previous_zoom := zoom
	var new_zoom_val := clampf(zoom.x * zoom_factor, EditorState.MIN_ZOOM, EditorState.MAX_ZOOM)
	var new_zoom := Vector2(new_zoom_val, new_zoom_val)

	# Keep the world point under the cursor fixed:
	# delta_position = screen_offset * (1/Z_old - 1/Z_new)
	var screen_offset := screen_pos - get_viewport_rect().size / 2.0
	position += screen_offset * (Vector2.ONE / previous_zoom - Vector2.ONE / new_zoom)
	zoom = new_zoom
	EditorState.current_camera_pos = position


func _on_pan_changed(screen_offset: Vector2) -> void:
	position += screen_offset / zoom
	EditorState.current_camera_pos = position
