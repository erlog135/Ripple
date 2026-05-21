extends Node

signal data_changed(by_user: bool, affected_frame: int)

var current_path: String = ""
var current_sequence: DrawCommandSequence

func set_current_sequence(sequence: DrawCommandSequence):
	current_sequence = sequence
	data_changed.emit(true, -1)

func get_current_image() -> DrawCommandImage:
	if current_sequence == null:
		return null

	var frames := current_sequence.frames
	var current_idx := EditorState.current_frame
	if current_idx < 0 or current_idx >= frames.size():
		return null

	return frames[current_idx]

func get_current_commands() -> Array:
	var image := get_current_image()
	if image == null:
		return []
	return image.commands
