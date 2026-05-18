class_name LinePenEditAction
extends EditAction

enum Mode {
	START_NEW,
	INSERT_POINT,
	CLOSE_PATH,
}

var _frame_index: int
var _mode: Mode

var _prev_selected_command_indices: Array[int]
var _prev_selected_point_indices: Dictionary

var _start_new_append_index: int
var _new_command_point: Vector2

var _command_index: int
var _insert_index: int
var _insert_point: Vector2

var _close_command_index: int
var _close_prev_path_open: bool = true


func _init_start_new(frame_index: int, point: Vector2, sel_commands: Array[int], sel_points: Dictionary) -> void:
	action_name = "Line Pen"
	_frame_index = frame_index
	_mode = Mode.START_NEW
	_new_command_point = point
	_capture_selection(sel_commands, sel_points)


func _init_insert(
	frame_index: int,
	command_index: int,
	insert_index: int,
	point: Vector2,
	sel_commands: Array[int],
	sel_points: Dictionary,
) -> void:
	action_name = "Line Pen"
	_frame_index = frame_index
	_mode = Mode.INSERT_POINT
	_command_index = command_index
	_insert_index = insert_index
	_insert_point = point
	_capture_selection(sel_commands, sel_points)


func _init_close_path(frame_index: int, command_index: int, sel_commands: Array[int], sel_points: Dictionary) -> void:
	action_name = "Line Pen"
	_frame_index = frame_index
	_mode = Mode.CLOSE_PATH
	_close_command_index = command_index
	_capture_selection(sel_commands, sel_points)
	var frame: DrawCommandImage = _frame_at(frame_index)
	if frame != null and command_index >= 0 and command_index < frame.commands.size():
		_close_prev_path_open = frame.commands[command_index].path_open


static func start_new(frame_index: int, point: Vector2, sel_commands: Array[int], sel_points: Dictionary) -> LinePenEditAction:
	var a := LinePenEditAction.new()
	a._init_start_new(frame_index, point, sel_commands, sel_points)
	a._start_new_append_index = a._commands_size(frame_index)
	return a


static func insert_point(
	frame_index: int,
	command_index: int,
	insert_index: int,
	point: Vector2,
	sel_commands: Array[int],
	sel_points: Dictionary,
) -> LinePenEditAction:
	var a := LinePenEditAction.new()
	a._init_insert(frame_index, command_index, insert_index, point, sel_commands, sel_points)
	return a


static func close_path(
	frame_index: int,
	command_index: int,
	sel_commands: Array[int],
	sel_points: Dictionary,
) -> LinePenEditAction:
	var a := LinePenEditAction.new()
	a._init_close_path(frame_index, command_index, sel_commands, sel_points)
	return a


func _capture_selection(sel_commands: Array[int], sel_points: Dictionary) -> void:
	_prev_selected_command_indices = sel_commands.duplicate()
	_prev_selected_point_indices = {}
	for k in sel_points:
		var arr: Variant = sel_points[k]
		if arr is Array:
			_prev_selected_point_indices[k] = (arr as Array).duplicate()


func _commands_size(frame_index: int) -> int:
	var frame := _frame_at(frame_index)
	if frame == null:
		return 0
	return frame.commands.size()


func _frame_at(frame_index: int) -> DrawCommandImage:
	var sequence := ProjectData.current_sequence
	if sequence == null:
		return null
	if frame_index < 0 or frame_index >= sequence.frames.size():
		return null
	return sequence.frames[frame_index]


func do_action() -> void:
	var frame := _frame_at(_frame_index)
	if frame == null:
		return

	match _mode:
		Mode.START_NEW:
			var cmd := _make_new_path_command(_new_command_point)
			frame.commands.insert(_start_new_append_index, cmd)
			EditorState.selected_command_indices = [_start_new_append_index]
			EditorState.selected_point_indices = {_start_new_append_index: [0]}
		Mode.INSERT_POINT:
			if _command_index < 0 or _command_index >= frame.commands.size():
				return
			var cmd: DrawCommand = frame.commands[_command_index]
			var pts := cmd.points
			var i := clampi(_insert_index, 0, pts.size())
			pts.insert(i, _insert_point)
			cmd.points = pts
			EditorState.selected_command_indices = [_command_index]
			EditorState.selected_point_indices = {_command_index: [i]}
		Mode.CLOSE_PATH:
			if _close_command_index < 0 or _close_command_index >= frame.commands.size():
				return
			var c: DrawCommand = frame.commands[_close_command_index]
			c.path_open = false

	ProjectData.data_changed.emit(false, _frame_index)
	EditorState.selection_changed.emit(false)


func undo_action() -> void:
	var frame := _frame_at(_frame_index)
	if frame == null:
		return

	match _mode:
		Mode.START_NEW:
			if _start_new_append_index >= 0 and _start_new_append_index < frame.commands.size():
				frame.commands.remove_at(_start_new_append_index)
		Mode.INSERT_POINT:
			if _command_index < 0 or _command_index >= frame.commands.size():
				pass
			else:
				var cmd: DrawCommand = frame.commands[_command_index]
				var pts := cmd.points
				if _insert_index >= 0 and _insert_index < pts.size():
					pts.remove_at(_insert_index)
					cmd.points = pts
		Mode.CLOSE_PATH:
			if _close_command_index >= 0 and _close_command_index < frame.commands.size():
				frame.commands[_close_command_index].path_open = _close_prev_path_open

	EditorState.selected_command_indices = _prev_selected_command_indices.duplicate()
	EditorState.selected_point_indices = {}
	for k in _prev_selected_point_indices:
		EditorState.selected_point_indices[k] = (_prev_selected_point_indices[k] as Array).duplicate()

	ProjectData.data_changed.emit(false, _frame_index)
	EditorState.selection_changed.emit(false)


func _make_new_path_command(point: Vector2) -> DrawCommand:
	var cmd := DrawCommand.new()
	cmd.draw_type = DrawCommand.Type.PRECISE_PATH
	cmd.hidden = false
	cmd.stroke_color = EditorState.current_stroke_color
	cmd.stroke_width = EditorState.current_stroke_width
	cmd.fill_color = EditorState.current_fill_color
	cmd.path_open = true
	cmd.circle_radius = 0
	cmd.points = PackedVector2Array([point])
	return cmd
