class_name ReorderFrameAction
extends EditAction

var _from_index: int
var _insert_index: int
var _prev_current_frame: int


func _init(from_index: int, insert_index_after_removal: int) -> void:
	action_name = "Reorder Frame"
	_from_index = from_index
	_insert_index = insert_index_after_removal


func do_action() -> void:
	_prev_current_frame = EditorState.current_frame
	_apply_move(_from_index, _insert_index)
	EditorState.set_current_frame(_remap_frame_index(_prev_current_frame, _from_index, _insert_index))
	ProjectData.data_changed.emit(false)


func undo_action() -> void:
	# Forward was: remove at _from_index, insert at _insert_index (final index of moved frame).
	# Reverse: remove at _insert_index, insert at _from_index.
	_apply_move(_insert_index, _from_index)
	EditorState.set_current_frame(_prev_current_frame)
	ProjectData.data_changed.emit(false)


func _apply_move(from_idx: int, insert_at: int) -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	if from_idx < 0 or from_idx >= sequence.frames.size():
		return
	var image: DrawCommandImage = sequence.frames[from_idx]
	var dur := int(sequence.frame_durations_ms[from_idx])
	sequence.frames.remove_at(from_idx)
	sequence.frame_durations_ms.remove_at(from_idx)
	var ins := clampi(insert_at, 0, sequence.frames.size())
	sequence.frames.insert(ins, image)
	sequence.frame_durations_ms.insert(ins, dur)


## [param final_idx] is the index of the moved frame after the move.
func _remap_frame_index(current: int, from_idx: int, final_idx: int) -> int:
	if current == from_idx:
		return final_idx
	if from_idx < final_idx:
		if current > from_idx and current <= final_idx:
			return current - 1
	else:
		if current >= final_idx and current < from_idx:
			return current + 1
	return current
