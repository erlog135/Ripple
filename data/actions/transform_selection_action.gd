class_name TransformSelectionAction
extends EditAction


## Applies a committed transform (move/scale/rotate) to selected commands.[br]
## [param new_points_arrays] and [param new_radii] align with [param command_indices]
## (same length, same order). A radius entry < 0 means "leave the circle radius unchanged".


var _frame_index: int
var _command_indices: Array[int]
var _new_points: Array = []
var _new_radii: Array = []
var _old_points: Array = []
var _old_radii: Array = []
## Command indices whose path_open should be set to false (endpoint-merge close).
var _close_indices: Array[int] = []
var _close_old_path_open: Array[bool] = []


func _init(
		frame_index: int,
		command_indices: Array[int],
		new_points_arrays: Array,
		new_radii: Array,
		close_indices: Array[int] = [],
	) -> void:
	action_name = "Transform"
	_frame_index = frame_index
	_command_indices = command_indices.duplicate()
	_new_points = new_points_arrays.duplicate()
	_new_radii = new_radii.duplicate()
	_close_indices = close_indices.duplicate()

	var sequence := ProjectData.current_sequence
	if not sequence:
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]
	for idx in _command_indices:
		var cmd: DrawCommand = frame.commands[idx]
		_old_points.append(cmd.points.duplicate())
		_old_radii.append(cmd.circle_radius)
	for idx in _close_indices:
		_close_old_path_open.append((frame.commands[idx] as DrawCommand).path_open)


func do_action() -> void:
	var sequence := ProjectData.current_sequence
	if not sequence:
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]
	for i in range(_command_indices.size()):
		var cmd: DrawCommand = frame.commands[_command_indices[i]]
		cmd.points = _new_points[i]
		if int(_new_radii[i]) >= 0:
			cmd.circle_radius = int(_new_radii[i])
	for idx in _close_indices:
		(frame.commands[idx] as DrawCommand).path_open = false
	ProjectData.data_changed.emit(false, _frame_index)


func undo_action() -> void:
	var sequence := ProjectData.current_sequence
	if not sequence:
		return
	var frame: DrawCommandImage = sequence.frames[_frame_index]
	for i in range(_command_indices.size()):
		var cmd: DrawCommand = frame.commands[_command_indices[i]]
		cmd.points = _old_points[i]
		cmd.circle_radius = int(_old_radii[i])
	for i in range(_close_indices.size()):
		(frame.commands[_close_indices[i]] as DrawCommand).path_open = _close_old_path_open[i]
	ProjectData.data_changed.emit(false, _frame_index)


static func create_image_flip(horizontal: bool) -> TransformSelectionAction:
	var image := ProjectData.get_current_image()
	if not image:
		return null
	var center := Vector2(image.bounds) / 2.0
	
	var sf := Vector2(-1, 1) if horizontal else Vector2(1, -1)
	var t := Transform2D.IDENTITY
	t.x = Vector2(sf.x, 0.0)
	t.y = Vector2(0.0, sf.y)
	t.origin = center - Vector2(sf.x * center.x, sf.y * center.y)
	
	return create_image_transform(t)


static func create_image_rotate(cw: bool) -> TransformSelectionAction:
	var image := ProjectData.get_current_image()
	if not image:
		return null
	var center := Vector2(image.bounds) / 2.0
	
	var ang := PI / 2.0 if cw else -PI / 2.0
	var t := Transform2D(ang, Vector2.ZERO)
	t.origin = center - t.basis_xform(center)
	
	return create_image_transform(t)


static func create_image_transform(matrix: Transform2D) -> TransformSelectionAction:
	var image := ProjectData.get_current_image()
	if not image:
		return null
	var frame_idx := EditorState.current_frame
	var command_indices: Array[int] = []
	var new_points_arrays: Array = []
	var new_radii: Array = []
	
	for i in range(image.commands.size()):
		command_indices.append(i)
	
	var radius_scale := (matrix.x.length() + matrix.y.length()) / 2.0
	
	for idx in command_indices:
		var cmd: DrawCommand = image.commands[idx]
		var transformed := cmd.points.duplicate()
		for pt_idx in range(transformed.size()):
			transformed[pt_idx] = matrix * cmd.points[pt_idx]
		new_points_arrays.append(transformed)
		
		var radius_new := -1
		if cmd.draw_type == DrawCommand.Type.CIRCLE:
			radius_new = maxi(1, roundi(float(cmd.circle_radius) * radius_scale))
		new_radii.append(radius_new)
		
	return TransformSelectionAction.new(frame_idx, command_indices, new_points_arrays, new_radii)

