class_name DuplicateFrameAction
extends EditAction

var _source_index: int
var _insert_index: int = -1


func _init(source_index: int) -> void:
	action_name = "Duplicate Frame"
	_source_index = source_index


func do_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	if _source_index < 0 or _source_index >= sequence.frames.size():
		return
	var copy := _copy_image(sequence.frames[_source_index])
	_insert_index = _source_index + 1
	sequence.frames.insert(_insert_index, copy)
	var dur := int(sequence.frame_durations_ms[_source_index])
	sequence.frame_durations_ms.insert(_insert_index, dur)
	ProjectData.data_changed.emit(false, -1)


func undo_action() -> void:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return
	if _insert_index < 0 or _insert_index >= sequence.frames.size():
		return
	sequence.frames.remove_at(_insert_index)
	sequence.frame_durations_ms.remove_at(_insert_index)
	ProjectData.data_changed.emit(false, -1)


func _copy_image(source: DrawCommandImage) -> DrawCommandImage:
	var image := DrawCommandImage.new()
	image.bounds = source.bounds
	for cmd in source.commands:
		image.commands.append(_copy_command(cmd))
	return image


func _copy_command(cmd: DrawCommand) -> DrawCommand:
	var c := DrawCommand.new()
	c.draw_type = cmd.draw_type
	c.hidden = cmd.hidden
	c.stroke_color = cmd.stroke_color
	c.stroke_width = cmd.stroke_width
	c.fill_color = cmd.fill_color
	c.path_open = cmd.path_open
	c.circle_radius = cmd.circle_radius
	c.points = cmd.points.duplicate()
	return c
