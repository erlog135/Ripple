extends Node2D

## Declared PDC bounds (artboard) in world space. Used as an alpha mask for [member CanvasItem.clip_children]
## when [member EditorState.clip_to_document_bounds] is set. Godot masks to the parent's drawn opacity, not a Rect2 property.
var _doc_bounds := Rect2()


func _ready() -> void:
	ProjectData.data_changed.connect(_on_data_changed)
	EditorState.current_frame_changed.connect(_on_frame_changed)
	EditorState.clip_to_bounds_changed.connect(_apply_clip_mode)
	_pull_bounds()
	_apply_clip_mode(EditorState.clip_to_document_bounds)


func _on_data_changed(_by_user: bool, _frame: int) -> void:
	_pull_bounds()


func _on_frame_changed(_frame_idx: int) -> void:
	_pull_bounds()


func _pull_bounds() -> void:
	var img := ProjectData.get_current_image()
	if img == null or img.bounds.x <= 0 or img.bounds.y <= 0:
		_doc_bounds = Rect2()
	else:
		_doc_bounds = Rect2(Vector2.ZERO, Vector2(img.bounds))
	queue_redraw()


func _apply_clip_mode(enabled: bool) -> void:
	clip_children = (
		CanvasItem.CLIP_CHILDREN_ONLY if enabled
		else CanvasItem.CLIP_CHILDREN_DISABLED
	)
	queue_redraw()


func _draw() -> void:
	if not EditorState.clip_to_document_bounds:
		return
	if _doc_bounds.size.x <= 0.0 or _doc_bounds.size.y <= 0.0:
		return
	# Fully opaque rectangle: masked region where Document children remain visible when clip_children is ONLY.
	draw_rect(_doc_bounds, Color.WHITE)
