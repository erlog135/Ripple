extends Control

@onready var image_dimensions: Label = $InfoLabels/ImageDimensions
@onready var file_size: Label = $InfoLabels/FileSize
@onready var cursor_position: Label = $InfoLabels/CursorPosition
@onready var selection_dimensions: Label = $InfoLabels/SelectionDimensions
@onready var zoom_level: Label = $InfoLabels/ZoomLevel


func _ready() -> void:
	EditorState.mouse_position_changed.connect(_on_mouse_position_changed)
	ProjectData.data_changed.connect(_on_data_changed)
	EditorState.zoom_changed.connect(_on_zoom_changed)
	EditorState.selection_changed.connect(_on_selection_changed)
	EditorState.drag_updated.connect(_on_drag_updated)

func _on_mouse_position_changed(screen_pos: Vector2) -> void:
	var canvas_center := get_rect().size / 2.0
	var pos : Vector2 = EditorState.current_camera_pos + (screen_pos - canvas_center) / EditorState.current_zoom
	cursor_position.text = "Cursor pos: %d, %d" % [pos.x, pos.y]

func _on_data_changed(_by_user: bool) -> void:
	var current_image: DrawCommandImage = ProjectData.get_current_image()
	if current_image == null:
		return
	var current_frame_bounds := current_image.bounds
	image_dimensions.text = "Image: %d x %d" % [current_frame_bounds.x, current_frame_bounds.y]

func _on_zoom_changed(_screen_pos: Vector2, _factor: float):
	zoom_level.text = "Zoom: %d%%" % int(EditorState.current_zoom*100.0)

func _on_selection_changed(_by_user: bool) -> void:
	_update_selection_dimensions()

func _on_drag_updated(_offset: Vector2, _dragging: bool) -> void:
	_update_selection_dimensions()

func _update_selection_dimensions() -> void:
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		selection_dimensions.hide()
		return

	var selected_positions: Array[Vector2] = []
	for cmd_idx in EditorState.selected_point_indices:
		var cmd: DrawCommand = frame.commands[cmd_idx]
		if cmd.hidden:
			continue
		for pt_idx in EditorState.selected_point_indices[cmd_idx]:
			if pt_idx < cmd.points.size():
				var pt: Vector2 = cmd.points[pt_idx]
				if EditorState.is_dragging_selection and EditorState.drag_offset != Vector2.ZERO:
					pt += EditorState.drag_offset
				selected_positions.append(pt)

	if selected_positions.size() < 2:
		selection_dimensions.hide()
		return

	var min_pos := selected_positions[0]
	var max_pos := selected_positions[0]
	for pos in selected_positions:
		min_pos = min_pos.min(pos)
		max_pos = max_pos.max(pos)

	var size := max_pos - min_pos
	selection_dimensions.text = "Selection: %d x %d" % [ceili(size.x), ceili(size.y)]
	selection_dimensions.show()
