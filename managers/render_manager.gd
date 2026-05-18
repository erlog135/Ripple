extends Node

signal preview_updated

# Key: DrawCommandImage.get_instance_id(), Value: ImageTexture.
# Keying by instance ID rather than frame index means reordering frames never
# invalidates the wrong cache entries.
var _frame_cache: Dictionary = {}
var _rasterizer := Rasterizer.new()

func _ready() -> void:
	ProjectData.data_changed.connect(_on_data_changed)

func _on_data_changed(_by_user: bool, affected_frame: int) -> void:
	# Use the explicitly reported frame index when available so that undo/redo
	# operations on non-active frames correctly drop their stale cache entries.
	# When affected_frame is -1 (structural changes), fall back to current frame.
	var seq := ProjectData.current_sequence
	if affected_frame >= 0 and seq != null and affected_frame < seq.frames.size():
		_frame_cache.erase(seq.frames[affected_frame].get_instance_id())
	else:
		var img := ProjectData.get_current_image()
		if img:
			_frame_cache.erase(img.get_instance_id())
	preview_updated.emit()

## Returns a cached ImageTexture for the given frame index, rendering it on first request.
func get_frame_texture(frame_index: int) -> ImageTexture:
	var seq := ProjectData.current_sequence
	if seq == null or frame_index < 0 or frame_index >= seq.frames.size():
		return null

	var image_data: DrawCommandImage = seq.frames[frame_index]
	var id := image_data.get_instance_id()

	if _frame_cache.has(id):
		return _frame_cache[id]

	var tex := _rasterizer.render(image_data)
	_frame_cache[id] = tex
	return tex

## Drops every cached texture and notifies listeners to redraw.
func invalidate_all() -> void:
	_frame_cache.clear()
	preview_updated.emit()
