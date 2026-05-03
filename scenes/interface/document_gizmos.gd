extends Node2D

const GRID_COLOR := Color(0.5, 0.5, 0.5, 1.0)

func _ready() -> void:
	ProjectData.data_changed.connect(_on_data_changed)
	EditorState.zoom_changed.connect(_on_zoom_changed)

func _on_data_changed(_by_user: bool) -> void:
	queue_redraw()

func _on_zoom_changed(_screen_pos: Vector2, _factor: float) -> void:
	queue_redraw()

func _draw() -> void:
	_draw_pixel_grid()

func _draw_pixel_grid() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null or sequence.frames.is_empty():
		return

	var bounds: Vector2i = sequence.frames[0].bounds
	if bounds.x <= 0 or bounds.y <= 0:
		return

	for x in range(0, bounds.x+1):
		draw_line(Vector2(x, 0), Vector2(x, bounds.y), GRID_COLOR, 1.0 / EditorState.current_zoom)

	for y in range(0, bounds.y+1):
		draw_line(Vector2(0, y), Vector2(bounds.x, y), GRID_COLOR, 1.0 / EditorState.current_zoom)
