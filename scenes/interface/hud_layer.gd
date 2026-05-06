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
