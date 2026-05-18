class_name ChangeFrameDelayAction
extends EditAction

var _frame_index: int
var _old_delay_ms: int
var _new_delay_ms: int


func _init(frame_index: int, old_delay_ms: int, new_delay_ms: int) -> void:
	action_name = "Change Frame Delay"
	_frame_index = frame_index
	_old_delay_ms = old_delay_ms
	_new_delay_ms = new_delay_ms


func do_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	if _frame_index < 0 or _frame_index >= sequence.frame_durations_ms.size():
		return
	sequence.frame_durations_ms[_frame_index] = _new_delay_ms
	ProjectData.data_changed.emit(false, -1)


func undo_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	if _frame_index < 0 or _frame_index >= sequence.frame_durations_ms.size():
		return
	sequence.frame_durations_ms[_frame_index] = _old_delay_ms
	ProjectData.data_changed.emit(false, -1)
