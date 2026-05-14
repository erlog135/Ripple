class_name AddFrameAction
extends EditAction

const DEFAULT_DURATION_MS := 33

var _insert_index: int


func _init(insert_index: int) -> void:
	action_name = "Add Frame"
	_insert_index = insert_index


func do_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	var idx := clampi(_insert_index, 0, sequence.frames.size())
	_insert_index = idx
	var image := _blank_image(sequence)
	sequence.frames.insert(idx, image)
	sequence.frame_durations_ms.insert(idx, DEFAULT_DURATION_MS)
	ProjectData.data_changed.emit(false)


func undo_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	var idx := clampi(_insert_index, 0, sequence.frames.size() - 1)
	if idx < 0 or idx >= sequence.frames.size():
		return
	sequence.frames.remove_at(idx)
	sequence.frame_durations_ms.remove_at(idx)
	ProjectData.data_changed.emit(false)


func _blank_image(sequence: DrawCommandSequence) -> DrawCommandImage:
	var image := DrawCommandImage.new()
	if sequence.frames.size() > 0:
		image.bounds = sequence.frames[0].bounds
	else:
		image.bounds = Vector2i(64, 64)
	image.commands = []
	return image
