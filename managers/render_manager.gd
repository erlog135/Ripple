extends Node

signal preview_updated
## Emitted before bulk rasterization begins. [param total] is the number of frames to rasterize.
signal bulk_raster_started(total: int)
## Emitted after each frame is cached during bulk rasterization.
signal bulk_raster_progress(completed: int, total: int)
## Emitted when all frames have been rasterized and [signal preview_updated] has fired.
signal bulk_raster_finished

## True while an async bulk rasterization pass is in progress.
var is_rasterizing := false

# Key: DrawCommandImage.get_instance_id(), Value: ImageTexture.
# Keying by instance ID rather than frame index means reordering frames never
# invalidates the wrong cache entries.
var _frame_cache: Dictionary = {}
var _rasterizer := Rasterizer.new()
var _preview_canvas_cached: Vector2i = Vector2i.ZERO
## World-space top-left of framebuffer pixel (0,0) when using sequence preview layout (see [method get_preview_raster_origin]).
var _preview_origin_cached: Vector2 = Vector2.ZERO
var _preview_canvas_valid := false
## Set true when preview canvas size/origin changes; listeners must refresh all frame thumbnails.
var preview_layout_changed := false

# Incremented on every bulk-raster request so superseded coroutines can self-terminate.
var _raster_version := 0

func _ready() -> void:
	ProjectData.data_changed.connect(_on_data_changed)

func _on_data_changed(_by_user: bool, affected_frame: int) -> void:
	preview_layout_changed = false
	var seq := ProjectData.current_sequence
	var layout_changed := false

	if seq != null and not seq.frames.is_empty():
		var new_layout := _rasterizer.compute_sequence_preview_layout(seq.frames)
		if (
			not _preview_canvas_valid
			or new_layout["size"] != _preview_canvas_cached
			or new_layout["origin"] != _preview_origin_cached
		):
			_preview_canvas_cached = new_layout["size"]
			_preview_origin_cached = new_layout["origin"]
			_preview_canvas_valid = true
			layout_changed = true
	else:
		_preview_canvas_valid = false
		_preview_origin_cached = Vector2.ZERO
		_preview_canvas_cached = Vector2i.ZERO
		layout_changed = true

	preview_layout_changed = layout_changed

	var needs_bulk := false
	if layout_changed or affected_frame < 0 or seq == null:
		_frame_cache.clear()
		needs_bulk = seq != null and not seq.frames.is_empty()
	elif affected_frame < seq.frames.size():
		_frame_cache.erase(seq.frames[affected_frame].get_instance_id())
	else:
		_frame_cache.clear()
		needs_bulk = seq != null and not seq.frames.is_empty()

	if needs_bulk:
		_raster_version += 1
		_rasterize_all_async(_raster_version)
	else:
		preview_updated.emit()


## Rasterizes every frame one per engine tick, yielding between each so the UI stays responsive.
## If a newer request supersedes this one ([member _raster_version] changes), the coroutine exits silently.
func _rasterize_all_async(version: int) -> void:
	is_rasterizing = true
	var seq := ProjectData.current_sequence
	if seq == null or seq.frames.is_empty():
		is_rasterizing = false
		preview_updated.emit()
		return

	var n := seq.frames.size()
	bulk_raster_started.emit(n)

	for i in n:
		if _raster_version != version:
			# A newer data_changed has already taken ownership of is_rasterizing.
			return
		get_frame_texture(i)
		bulk_raster_progress.emit(i + 1, n)
		await get_tree().process_frame

	if _raster_version == version:
		is_rasterizing = false
		preview_updated.emit()
		bulk_raster_finished.emit()

## Returns a cached ImageTexture for the given frame index, rendering it on first request.
func get_frame_texture(frame_index: int) -> ImageTexture:
	var seq := ProjectData.current_sequence
	if seq == null or frame_index < 0 or frame_index >= seq.frames.size():
		return null

	var image_data: DrawCommandImage = seq.frames[frame_index]
	var id := image_data.get_instance_id()

	if _frame_cache.has(id):
		return _frame_cache[id]

	if not _preview_canvas_valid:
		var layout := _rasterizer.compute_sequence_preview_layout(seq.frames)
		_preview_canvas_cached = layout["size"]
		_preview_origin_cached = layout["origin"]
		_preview_canvas_valid = true

	var tex := _rasterizer.render(image_data, _preview_canvas_cached, _preview_origin_cached)
	_frame_cache[id] = tex
	return tex


## World position of the top-left of raster preview textures ([member _preview_origin_cached]) so OOB (negative) coords stay aligned with the vector layer.
func get_preview_raster_origin() -> Vector2:
	return _preview_origin_cached

## Drops every cached texture and notifies listeners to redraw.
func invalidate_all() -> void:
	_frame_cache.clear()
	_preview_canvas_valid = false
	_preview_origin_cached = Vector2.ZERO
	preview_layout_changed = true
	preview_updated.emit()
