extends Node

signal pdc_loaded(pdc: DrawCommandSequence)

func _ready():
	pdc_loaded.connect(func(pdc: DrawCommandSequence): ProjectData.set_current_sequence(pdc))

func new_file():
	print_debug("hi")

func load_project(path):
	pass

func open_file_dialog():
	var file_dialog = FileDialog.new()
	get_tree().root.add_child(file_dialog)
	file_dialog.file_selected.connect(func(path: String): pdc_to_gd(path))

	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.pdc", "*.pdcs"]
	
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
		if type_val == DrawCommand.type.PRECISE_PATH:
			points.append(Vector2(x / 8.0, y / 8.0))
		else:
			points.append(Vector2(x, y))

	var cmd = DrawCommand.new()
	cmd.draw_type = type_val
	cmd.hidden = (flags & 1) != 0
	cmd.stroke_color = _pdc_color(stroke_color_val)
	cmd.stroke_width = stroke_width_val
	cmd.fill_color = _pdc_color(fill_color_val)
	cmd.points = points
	if type_val == DrawCommand.type.CIRCLE:
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

func save_project(path):
	pass

func export_frame(path):
	pass
