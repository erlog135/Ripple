extends Control

@onready var image: Sprite2D = $Panel/Control/PreviewClip/PreviewOrigin/Image
@onready var background_color: ColorRect = $Panel/Control/BackgroundColor


func _ready() -> void:
	EditorState.current_frame_changed.connect(_on_current_frame_changed)
	EditorState.bg_color_changed.connect(_on_bg_color_changed)
	EditorState.clip_to_bounds_changed.connect(_on_clip_to_bounds_changed)
	RenderManager.preview_updated.connect(_on_preview_updated)
	ProjectData.data_changed.connect(_on_data_changed)

	_update_preview()


func _on_current_frame_changed(_frame: int) -> void:
	_update_preview()


func _on_bg_color_changed() -> void:
	_update_preview()


func _on_clip_to_bounds_changed(_enabled: bool) -> void:
	_update_preview()


func _on_preview_updated() -> void:
	_update_preview()


func _on_data_changed(_by_user: bool, _affected_frame: int) -> void:
	_update_preview()


func _update_preview() -> void:
	background_color.color = EditorState.current_bg_color

	var image_data := ProjectData.get_current_image()
	var tex := RenderManager.get_frame_texture(EditorState.current_frame)
	image.texture = tex

	if image_data == null or tex == null:
		image.region_enabled = false
		image.position = Vector2.ZERO
		return

	var doc_size := Vector2(image_data.bounds)
	var raster_origin := RenderManager.get_preview_raster_origin()

	if EditorState.clip_to_document_bounds:
		image.region_enabled = true
		image.region_rect = Rect2(-raster_origin, doc_size)
		image.position = Vector2.ZERO
	else:
		image.region_enabled = false
		var tex_size := tex.get_size()
		image.position = raster_origin + (tex_size / 2.0) - (doc_size / 2.0)
