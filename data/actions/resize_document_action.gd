class_name ResizeDocumentAction
extends EditAction

## Resizes the document bounds for every frame in the sequence and shifts all
## existing geometry so it stays anchored relative to the new canvas.
##
## A resize is a pure translation, so undo just re-applies the inverse offset and
## restores the old bounds: no deep copies of every frame are needed. The offset
## is rounded once at construction so do/undo/redo are exact inverses even when a
## centered anchor lands on a half-pixel.

var _old_size: Vector2i
var _new_size: Vector2i
var _content_offset: Vector2


## [param target_size] is the new document bounds. [param anchor_percentage] maps
## the 9-point anchor to where existing content sticks (e.g. Vector2(0, 0) for
## top-left, Vector2(0.5, 0.5) for center, Vector2(1, 1) for bottom-right).
func _init(target_size: Vector2i, anchor_percentage: Vector2) -> void:
	action_name = "Resize Document"
	var sequence := ProjectData.current_sequence
	if sequence != null and not sequence.frames.is_empty():
		_old_size = sequence.frames[0].bounds
	_new_size = target_size
	var delta := Vector2(_new_size - _old_size)
	_content_offset = (delta * anchor_percentage).round()


func do_action() -> void:
	_apply(_new_size, _content_offset)


func undo_action() -> void:
	_apply(_old_size, -_content_offset)


func _apply(size: Vector2i, offset: Vector2) -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	for frame: DrawCommandImage in sequence.frames:
		frame.bounds = size
		if offset == Vector2.ZERO:
			continue
		for cmd: DrawCommand in frame.commands:
			var pts := cmd.points.duplicate()
			for i in range(pts.size()):
				pts[i] += offset
			cmd.points = pts
	ProjectData.data_changed.emit(false, -1)
