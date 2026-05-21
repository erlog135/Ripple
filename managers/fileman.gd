extends Node

signal pdc_loaded(pdc: DrawCommandSequence)
signal file_loaded(size_bytes: int)
signal file_saved(size_bytes: int)

func _ready():
	pdc_loaded.connect(func(pdc: DrawCommandSequence):
		ProjectData.set_current_sequence(pdc)
		EditorState.fit_document_to_view()
	)

func new_file():
	print_debug("hi")

func load_project(path: String) -> void:
	pdc_to_gd(path)

func save_file() -> void:
	if ProjectData.current_path.is_empty():
		save_as_file_dialog()
	else:
		gd_to_pdc(ProjectData.current_path, ProjectData.current_sequence)

func open_file_dialog():
	var file_dialog = FileDialog.new()
	get_tree().root.add_child(file_dialog)
	file_dialog.file_selected.connect(func(path: String): pdc_to_gd(path))

	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.pdc", "*.pdcs"]
	file_dialog.use_native_dialog = true
	
	file_dialog.popup_centered()

func save_as_file_dialog():
	var file_dialog = FileDialog.new()
	get_tree().root.add_child(file_dialog)
	file_dialog.file_selected.connect(func(path: String): gd_to_pdc(path, ProjectData.current_sequence))

	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.pdc", "*.pdcs"]
	file_dialog.use_native_dialog = true

	file_dialog.popup_centered()

func pdc_to_gd(path: String) -> DrawCommandSequence:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open PDC file: " + path)
		return null

	file.set_big_endian(false)
	var magic = file.get_buffer(4).get_string_from_ascii()
	file.get_32()  # total data size, unused

	var sequence = DrawCommandSequence.new()

	if magic == "PDCI":
		var image = _pdc_parse_image(file)
		sequence.frames.append(image)
		sequence.frame_durations_ms.append(0)
	elif magic == "PDCS":
		_pdc_parse_sequence(file, sequence)
	else:
		push_error("Unknown PDC magic word: " + magic)
		return null

	ProjectData.current_path = path
	file_loaded.emit(file.get_length())
	pdc_loaded.emit(sequence)
	return sequence

func _pdc_parse_image(file: FileAccess) -> DrawCommandImage:
	file.get_8()  # version
	file.get_8()  # reserved
	var image = DrawCommandImage.new()
	image.bounds = Vector2i(_pdc_int16(file), _pdc_int16(file))
	image.commands = _pdc_parse_command_list(file)
	return image

func _pdc_parse_sequence(file: FileAccess, sequence: DrawCommandSequence) -> void:
	file.get_8()  # version
	file.get_8()  # reserved
	var bounds = Vector2i(_pdc_int16(file), _pdc_int16(file))
	sequence.play_count = file.get_16()
	var frame_count = file.get_16()
	for _i in range(frame_count):
		var duration = file.get_16()
		var image = DrawCommandImage.new()
		image.bounds = bounds
		image.commands = _pdc_parse_command_list(file)
		sequence.frames.append(image)
		sequence.frame_durations_ms.append(duration)

func _pdc_parse_command_list(file: FileAccess) -> Array[DrawCommand]:
	var commands: Array[DrawCommand] = []
	var num_commands = file.get_16()
	for _i in range(num_commands):
		commands.append(_pdc_parse_command(file))
	return commands

func _pdc_parse_command(file: FileAccess) -> DrawCommand:
	var type_val = file.get_8()
	var flags = file.get_8()
	var stroke_color_val = file.get_8()
	var stroke_width_val = file.get_8()
	var fill_color_val = file.get_8()
	var path_open_or_radius = file.get_16()
	var num_points = file.get_16()

	var points = PackedVector2Array()
	for _i in range(num_points):
		var x = _pdc_int16(file)
		var y = _pdc_int16(file)
		if type_val == DrawCommand.Type.PRECISE_PATH:
			points.append(Vector2(x / 8.0 + 0.5, y / 8.0 + 0.5))
		else:
			points.append(Vector2(x, y))

	var cmd = DrawCommand.new()
	cmd.draw_type = type_val
	cmd.hidden = (flags & 1) != 0
	cmd.stroke_color = _pdc_color(stroke_color_val)
	cmd.stroke_width = stroke_width_val
	cmd.fill_color = _pdc_color(fill_color_val)
	cmd.points = points
	if type_val == DrawCommand.Type.CIRCLE:
		cmd.circle_radius = path_open_or_radius
	else:
		cmd.path_open = (path_open_or_radius & 1) != 0
	return cmd

func _pdc_int16(file: FileAccess) -> int:
	var val = file.get_16()
	if val > 32767:
		val -= 65536
	return val

func _pdc_color(val: int) -> Color:
	var a_val = (val >> 6) & 3
	var r_val = (val >> 4) & 3
	var g_val = (val >> 2) & 3
	var b_val = val & 3
	return Color(r_val / 3.0, g_val / 3.0, b_val / 3.0, a_val / 3.0)

func gd_to_pdc(path: String, sequence: DrawCommandSequence) -> bool:
	if sequence == null or sequence.frames.is_empty():
		push_error("Cannot export empty sequence")
		return false

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open file for writing: " + path)
		return false

	file.set_big_endian(false)

	if sequence.frames.size() == 1:
		file.store_buffer("PDCI".to_ascii_buffer())
		file.store_32(_pdc_image_data_size(sequence.frames[0]))
		_pdc_write_image(file, sequence.frames[0])
	else:
		file.store_buffer("PDCS".to_ascii_buffer())
		file.store_32(_pdc_sequence_data_size(sequence))
		_pdc_write_sequence(file, sequence)

	ProjectData.current_path = path
	file_saved.emit(file.get_position())
	return true

func _pdc_write_image(file: FileAccess, image: DrawCommandImage) -> void:
	file.store_8(1)  # version
	file.store_8(0)  # reserved
	_pdc_write_int16(file, image.bounds.x)
	_pdc_write_int16(file, image.bounds.y)
	_pdc_write_command_list(file, image.commands)

func _pdc_write_sequence(file: FileAccess, sequence: DrawCommandSequence) -> void:
	file.store_8(1)  # version
	file.store_8(0)  # reserved
	var bounds = sequence.frames[0].bounds
	_pdc_write_int16(file, bounds.x)
	_pdc_write_int16(file, bounds.y)
	file.store_16(sequence.play_count)
	file.store_16(sequence.frames.size())
	for i in range(sequence.frames.size()):
		var duration = sequence.frame_durations_ms[i] if i < sequence.frame_durations_ms.size() else 0
		file.store_16(duration)
		_pdc_write_command_list(file, sequence.frames[i].commands)

func _pdc_write_command_list(file: FileAccess, commands: Array[DrawCommand]) -> void:
	file.store_16(commands.size())
	for cmd in commands:
		_pdc_write_command(file, cmd)

func _pdc_write_command(file: FileAccess, cmd: DrawCommand) -> void:
	file.store_8(cmd.draw_type)
	file.store_8(1 if cmd.hidden else 0)
	file.store_8(_pdc_color_encode(cmd.stroke_color))
	file.store_8(cmd.stroke_width)
	file.store_8(_pdc_color_encode(cmd.fill_color))
	if cmd.draw_type == DrawCommand.Type.CIRCLE:
		file.store_16(cmd.circle_radius)
	else:
		file.store_16(1 if cmd.path_open else 0)
	file.store_16(cmd.points.size())
	for pt in cmd.points:
		if cmd.draw_type == DrawCommand.Type.PRECISE_PATH:
			_pdc_write_int16(file, roundi((pt.x - 0.5) * 8))
			_pdc_write_int16(file, roundi((pt.y - 0.5) * 8))
		else:
			_pdc_write_int16(file, roundi(pt.x))
			_pdc_write_int16(file, roundi(pt.y))

func _pdc_write_int16(file: FileAccess, val: int) -> void:
	file.store_16(val & 0xFFFF)

func _pdc_color_encode(color: Color) -> int:
	var a = clampi(roundi(color.a * 3), 0, 3)
	var r = clampi(roundi(color.r * 3), 0, 3)
	var g = clampi(roundi(color.g * 3), 0, 3)
	var b = clampi(roundi(color.b * 3), 0, 3)
	return (a << 6) | (r << 4) | (g << 2) | b

func _pdc_command_size(cmd: DrawCommand) -> int:
	return 9 + cmd.points.size() * 4

func _pdc_command_list_size(commands: Array[DrawCommand]) -> int:
	var size = 2  # num_commands uint16
	for cmd in commands:
		size += _pdc_command_size(cmd)
	return size

func _pdc_image_data_size(image: DrawCommandImage) -> int:
	return 6 + _pdc_command_list_size(image.commands)  # version + reserved + viewbox

func _pdc_sequence_data_size(sequence: DrawCommandSequence) -> int:
	var size = 10  # version + reserved + viewbox + play_count + frame_count
	for image in sequence.frames:
		size += 2 + _pdc_command_list_size(image.commands)  # duration + command list
	return size

func save_project(path: String) -> void:
	gd_to_pdc(path, ProjectData.current_sequence)

func export_frame(path):
	pass
