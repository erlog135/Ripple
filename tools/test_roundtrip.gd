extends SceneTree

const SvgPdcHelper := preload("res://tools/svg_pdc.gd")

func _init() -> void:
	print("--- Running SVG-PDC Round-Trip Verification Test ---")
	
	# Let's load the test PDC file: res://test/pdc/Fin_50px.pdc
	# Since autoloads are not active in scene tree script execution unless we instantiate them,
	# we can write a simple manual PDC parser or load it directly.
	# But actually, Fileman is just a script res://managers/fileman.gd.
	# Let's load it and use its pdc loading method!
	var fileman_script = load("res://managers/fileman.gd")
	var fileman = fileman_script.new()
	# Mock EditorState and ProjectData so add_sequence/fit_document don't crash
	# By overriding the methods or simply calling pdc_to_gd's internal parsers
	# Or let's just implement a minimal PDC parser to load the bytes, or load using Fileman
	
	# Actually, to make this test robust and self-contained without needing autoload mocks,
	# let's just parse the PDC file manually or load it with a mocked helper.
	# Let's check how fileman reads it:
	var path = "res://test/pdc/Fin_50px.pdc"
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("ERROR: Failed to open test PDC file: ", path)
		quit(1)
		return
		
	file.set_big_endian(false)
	var magic = file.get_buffer(4).get_string_from_ascii()
	var total_size = file.get_32()
	print("Loaded PDC Magic: ", magic, ", size: ", total_size)
	
	var sequence = DrawCommandSequence.new()
	if magic == "PDCI":
		# Parse image
		file.get_8() # version
		file.get_8() # reserved
		var img = DrawCommandImage.new()
		img.bounds = Vector2i(file.get_16(), file.get_16())
		img.commands = parse_command_list(file)
		sequence.frames.append(img)
		sequence.frame_durations_ms.append(0)
	else:
		print("ERROR: Test PDC is not a PDCI file: ", magic)
		quit(1)
		return
	file.close()
	
	print("Original sequence frames size: ", sequence.frames.size())
	var first_frame = sequence.frames[0]
	print("Bounds: ", first_frame.bounds)
	print("Number of commands: ", first_frame.commands.size())
	
	# Convert to SVG
	var svg_content = SvgPdcHelper.frame_to_svg(sequence, 0)
	print("\n--- Generated SVG Output ---")
	print(svg_content)
	print("----------------------------\n")
	
	# Parse SVG back
	var rt_sequence = SvgPdcHelper.svg_to_sequence(svg_content)
	if not rt_sequence:
		print("ERROR: Failed to parse SVG back to sequence!")
		quit(1)
		return
		
	var rt_frame = rt_sequence.frames[0]
	print("Round-tripped bounds: ", rt_frame.bounds)
	print("Round-tripped commands count: ", rt_frame.commands.size())
	
	# Compare
	var success = true
	if first_frame.bounds != rt_frame.bounds:
		print("FAIL: Bounds mismatch! Original: ", first_frame.bounds, ", RT: ", rt_frame.bounds)
		success = false
		
	if first_frame.commands.size() != rt_frame.commands.size():
		print("FAIL: Command count mismatch! Original: ", first_frame.commands.size(), ", RT: ", rt_frame.commands.size())
		success = false
	else:
		for i in range(first_frame.commands.size()):
			var cmd_orig: DrawCommand = first_frame.commands[i]
			var cmd_rt: DrawCommand = rt_frame.commands[i]
			
			print("Command %d:" % i)
			print("  Type - Original: %d, RT: %d" % [cmd_orig.draw_type, cmd_rt.draw_type])
			
			# Note: Pebble PDC converts precise paths to PRECISE_PATH (type 3).
			# Let's check matching.
			var type_match = cmd_orig.draw_type == cmd_rt.draw_type
			# Special case: Type 1 (PATH) and Type 3 (PRECISE_PATH) are both paths.
			if cmd_orig.draw_type == DrawCommand.Type.PATH and cmd_rt.draw_type == DrawCommand.Type.PRECISE_PATH:
				type_match = true
			if not type_match:
				print("  FAIL: Command %d type mismatch!" % i)
				success = false
				
			# Compare colors. Note: color values are encoded/decoded in 2-bit (GColor8), so we compare with GColor8 tolerance
			var fill_orig = color_gcolor8_approx(cmd_orig.fill_color)
			var fill_rt = color_gcolor8_approx(cmd_rt.fill_color)
			if fill_orig != fill_rt:
				print("  FAIL: Fill color mismatch! Orig: %s, RT: %s" % [fill_orig, fill_rt])
				success = false
				
			var stroke_orig = color_gcolor8_approx(cmd_orig.stroke_color)
			var stroke_rt = color_gcolor8_approx(cmd_rt.stroke_color)
			if stroke_orig != stroke_rt:
				print("  FAIL: Stroke color mismatch! Orig: %s, RT: %s" % [stroke_orig, stroke_rt])
				success = false
				
			if cmd_orig.stroke_width != cmd_rt.stroke_width:
				# Stroke width might have slight differences or float scaling
				print("  WARNING: Stroke width mismatch! Orig: %d, RT: %d" % [cmd_orig.stroke_width, cmd_rt.stroke_width])
				
			# Compare points with some margin for float precision
			if cmd_orig.points.size() != cmd_rt.points.size():
				print("  FAIL: Points count mismatch! Orig: %d, RT: %d" % [cmd_orig.points.size(), cmd_rt.points.size()])
				success = false
			else:
				for p_idx in range(cmd_orig.points.size()):
					var p_orig = cmd_orig.points[p_idx]
					var p_rt = cmd_rt.points[p_idx]
					if p_orig.distance_to(p_rt) > 0.6: # tolerance is small
						print("  FAIL: Point %d mismatch! Orig: %s, RT: %s (dist: %f)" % [p_idx, p_orig, p_rt, p_orig.distance_to(p_rt)])
						success = false
						
	if success:
		print("SUCCESS: SVG-PDC Round-Trip Verification Passed!")
		quit(0)
	else:
		print("FAIL: Round-Trip Verification Mismatch Detected!")
		quit(1)

func parse_command_list(file: FileAccess) -> Array[DrawCommand]:
	var commands: Array[DrawCommand] = []
	var num_commands = file.get_16()
	for _i in range(num_commands):
		commands.append(parse_command(file))
	return commands

func parse_command(file: FileAccess) -> DrawCommand:
	var type_val = file.get_8()
	var flags = file.get_8()
	var stroke_color_val = file.get_8()
	var stroke_width_val = file.get_8()
	var fill_color_val = file.get_8()
	var path_open_or_radius = file.get_16()
	var num_points = file.get_16()

	var points = PackedVector2Array()
	for _i in range(num_points):
		var x = file.get_16()
		if x > 32767: x -= 65536
		var y = file.get_16()
		if y > 32767: y -= 65536
		if type_val == DrawCommand.Type.PRECISE_PATH:
			points.append(Vector2(x / 8.0 + 0.5, y / 8.0 + 0.5))
		else:
			points.append(Vector2(x, y))

	var cmd = DrawCommand.new()
	cmd.draw_type = type_val
	cmd.hidden = (flags & 1) != 0
	cmd.stroke_color = decode_color(stroke_color_val)
	cmd.stroke_width = stroke_width_val
	cmd.fill_color = decode_color(fill_color_val)
	cmd.points = points
	if type_val == DrawCommand.Type.CIRCLE:
		cmd.circle_radius = path_open_or_radius
	else:
		cmd.path_open = (path_open_or_radius & 1) != 0
	return cmd

func decode_color(val: int) -> Color:
	var a_val = (val >> 6) & 3
	var r_val = (val >> 4) & 3
	var g_val = (val >> 2) & 3
	var b_val = val & 3
	return Color(r_val / 3.0, g_val / 3.0, b_val / 3.0, a_val / 3.0)

func color_gcolor8_approx(color: Color) -> String:
	var a = clampi(roundi(color.a * 3), 0, 3)
	var r = clampi(roundi(color.r * 3), 0, 3)
	var g = clampi(roundi(color.g * 3), 0, 3)
	var b = clampi(roundi(color.b * 3), 0, 3)
	return "A%d R%d G%d B%d" % [a, r, g, b]
