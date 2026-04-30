extends Control

@onready var image_dimensions: Label = $InfoLabels/ImageDimensions
@onready var file_size: Label = $InfoLabels/FileSize
@onready var cursor_position: Label = $InfoLabels/CursorPosition
@onready var selection_dimensions: Label = $InfoLabels/SelectionDimensions

func _ready() -> void:
	EditorState.mouse_position_changed.connect(_on_mouse_position_changed)

	ProjectData.data_changed.connect(_on_data_changed)

func _on_mouse_position_changed(screen_pos: Vector2) -> void:
	var canvas_center := get_rect().size / 2.0
	var pos : Vector2 = EditorState.current_camera_pos + (screen_pos - canvas_center) / EditorState.current_zoom
	cursor_position.text = "Cursor pos: %d, %d" % [pos.x, pos.y]

func _on_data_changed(by_user: bool) -> void:
	var current_frame_bounds := ProjectData.current_sequence.frames[EditorState.current_frame].bounds
	image_dimensions.text = "Image: %d x %d" % [current_frame_bounds.x, current_frame_bounds.y]
