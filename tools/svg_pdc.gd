class_name SvgPdc extends RefCounted

## SVG to/from PDC helper converter class.

# Evaluates a cubic bezier curve at parameter t (0.0 to 1.0)
static func evaluate_cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var omt = 1.0 - t
	return omt * omt * omt * p0 + 3.0 * omt * omt * t * p1 + 3.0 * omt * t * t * p2 + t * t * t * p3

# Evaluates a quadratic bezier curve at parameter t (0.0 to 1.0)
static func evaluate_quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var omt = 1.0 - t
	return omt * omt * p0 + 2.0 * omt * t * p1 + t * t * p2

# Tokenizes an SVG path 'd' string into a sequence of commands and float values
static func tokenize_path(d: String) -> Array:
	var tokens = []
	var i = 0
	var n = d.length()
	while i < n:
		var c = d[i]
		if c == ' ' or c == ',' or c == '\t' or c == '\n' or c == '\r':
			i += 1
			continue
		
		# Match command character
		if "MmLlHhVvCcSsQqTtAazZ".contains(c):
			tokens.append(c)
			i += 1
			continue
		
		# Parse float number (supports signs, decimals, and scientific notation)
		var start = i
		if d[i] == '-' or d[i] == '+':
			i += 1
		var has_dot = false
		var has_e = false
		while i < n:
			var cc = d[i]
			if cc >= '0' and cc <= '9':
				i += 1
			elif cc == '.' and not has_dot:
				has_dot = true
				i += 1
			elif (cc == 'e' or cc == 'E') and not has_e:
				has_e = true
				i += 1
				if i < n and (d[i] == '-' or d[i] == '+'):
					i += 1
			else:
				break
		if i > start:
			var num_str = d.substr(start, i - start)
			tokens.append(num_str.to_float())
		else:
			# Skip unrecognized characters to avoid infinite loops
			i += 1
	return tokens

# Parses SVG transform attribute into a Transform2D
static func parse_transform(transform_str: String) -> Transform2D:
	var combined_transform := Transform2D.IDENTITY
	
	var regex := RegEx.new()
	# Match functionName(arguments)
	regex.compile("([a-zA-Z]+)\\s*\\(([^)]+)\\)")
	
	var matches := regex.search_all(transform_str)
	for m in matches:
		var cmd = m.get_string(1).strip_edges().to_lower()
		var args_str = m.get_string(2).strip_edges()
		
		# Extract numbers
		var arg_regex = RegEx.new()
		arg_regex.compile("([-\\d.eE+]+)")
		var arg_matches = arg_regex.search_all(args_str)
		var args: Array[float] = []
		for am in arg_matches:
			args.append(am.get_string(0).to_float())
			
		match cmd:
			"translate":
				var tx = args[0] if args.size() > 0 else 0.0
				var ty = args[1] if args.size() > 1 else 0.0
				combined_transform = combined_transform.translated(Vector2(tx, ty))
			"scale":
				var sx = args[0] if args.size() > 0 else 1.0
				var sy = args[1] if args.size() > 1 else sx
				combined_transform = combined_transform.scaled(Vector2(sx, sy))
			"rotate":
				var angle = args[0] if args.size() > 0 else 0.0
				if args.size() >= 3:
					var cx = args[1]
					var cy = args[2]
					combined_transform = combined_transform.translated(Vector2(cx, cy)).rotated(deg_to_rad(angle)).translated(Vector2(-cx, -cy))
				else:
					combined_transform = combined_transform.rotated(deg_to_rad(angle))
			"matrix":
				if args.size() >= 6:
					var a = args[0]
					var b = args[1]
					var c = args[2]
					var d = args[3]
					var e = args[4]
					var f = args[5]
					var mat_trans = Transform2D(Vector2(a, b), Vector2(c, d), Vector2(e, f))
					combined_transform = combined_transform * mat_trans
	return combined_transform

# Parses style declarations and properties
static func parse_style_attributes(attributes: Dictionary, base_style: Dictionary) -> Dictionary:
	var style = base_style.duplicate()
	
	if attributes.has("style"):
		var style_parts = attributes["style"].split(";")
		for part in style_parts:
			var kv = part.split(":")
			if kv.size() == 2:
				var k = kv[0].strip_edges()
				var v = kv[1].strip_edges()
				attributes[k] = v
				
	if attributes.has("fill"):
		var val = attributes["fill"].strip_edges()
		if val == "none":
			style["fill"] = Color(0, 0, 0, 0)
		else:
			style["fill"] = Color.from_string(val, Color.BLACK)
			
	if attributes.has("stroke"):
		var val = attributes["stroke"].strip_edges()
		if val == "none":
			style["stroke"] = Color(0, 0, 0, 0)
		else:
			style["stroke"] = Color.from_string(val, Color(0, 0, 0, 0))
			
	if attributes.has("stroke-width"):
		style["stroke_width"] = roundi(attributes["stroke-width"].to_float())
		
	if attributes.has("opacity"):
		style["opacity"] = attributes["opacity"].to_float()
		
	if attributes.has("fill-opacity"):
		style["fill_opacity"] = attributes["fill-opacity"].to_float()
		
	if attributes.has("stroke-opacity"):
		style["stroke_opacity"] = attributes["stroke-opacity"].to_float()
		
	return style

# Applies parsed style properties (handling opacity blending) to a DrawCommand
static func apply_command_styles(cmd: DrawCommand, style: Dictionary) -> void:
	var op = style.get("opacity", 1.0)
	var fill_op = style.get("fill_opacity", 1.0) * op
	var stroke_op = style.get("stroke_opacity", 1.0) * op
	
	var fc: Color = style.get("fill", Color.BLACK)
	var fc_copy = fc
	fc_copy.a *= fill_op
	cmd.fill_color = fc_copy
	
	var sc: Color = style.get("stroke", Color(0, 0, 0, 0))
	var sc_copy = sc
	sc_copy.a *= stroke_op
	cmd.stroke_color = sc_copy
	
	cmd.stroke_width = style.get("stroke_width", 1)
	cmd.hidden = false

# Factory method to create a DrawCommand from points and state
static func create_draw_command(draw_type: DrawCommand.Type, pts: PackedVector2Array, path_open: bool, state: Dictionary) -> DrawCommand:
	var cmd = DrawCommand.new()
	cmd.draw_type = draw_type
	cmd.path_open = path_open
	
	var tx_pts = PackedVector2Array()
	tx_pts.resize(pts.size())
	var trans = state["transform"]
	for i in range(pts.size()):
		tx_pts[i] = trans * pts[i]
	cmd.points = tx_pts
	
	apply_command_styles(cmd, state["style"])
	return cmd

# Helper to parse spacing/comma list of points in polyline/polygon attributes
static func parse_points_attribute(points_str: String) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var regex = RegEx.new()
	regex.compile("([-\\d.]+)")
	var matches = regex.search_all(points_str)
	var i = 0
	while i + 1 < matches.size():
		var x = matches[i].get_string(0).to_float()
		var y = matches[i+1].get_string(0).to_float()
		pts.append(Vector2(x, y))
		i += 2
	return pts

# Parses SVG path command tokens into DrawCommand objects
static func parse_svg_path(d: String, state: Dictionary) -> Array[DrawCommand]:
	var commands: Array[DrawCommand] = []
	var tokens = tokenize_path(d)
	
	var current_point := Vector2.ZERO
	var start_point := Vector2.ZERO
	var last_control_point := Vector2.ZERO
	var last_command := ""
	var subpath_points := PackedVector2Array()
	
	var idx = 0
	var active_cmd = ""
	
	while idx < tokens.size():
		var token = tokens[idx]
		var is_cmd_char = false
		if typeof(token) == TYPE_STRING:
			is_cmd_char = true
			active_cmd = token
			idx += 1
		
		if active_cmd == "":
			if not is_cmd_char:
				idx += 1
			continue
			
		match active_cmd:
			"M", "m":
				if idx + 1 >= tokens.size():
					break
				var p := Vector2(tokens[idx], tokens[idx+1])
				idx += 2
				if active_cmd == "m":
					p += current_point
					
				if subpath_points.size() > 0:
					var cmd = create_draw_command(DrawCommand.Type.PRECISE_PATH, subpath_points, true, state)
					commands.append(cmd)
					subpath_points = PackedVector2Array()
					
				current_point = p
				start_point = p
				subpath_points.append(p)
				last_command = active_cmd
				
				if active_cmd == "M":
					active_cmd = "L"
				else:
					active_cmd = "l"
					
			"L", "l":
				if idx + 1 >= tokens.size():
					break
				var p := Vector2(tokens[idx], tokens[idx+1])
				idx += 2
				if active_cmd == "l":
					p += current_point
				subpath_points.append(p)
				current_point = p
				last_command = active_cmd
				
			"H", "h":
				if idx >= tokens.size():
					break
				var val = tokens[idx]
				idx += 1
				if active_cmd == "h":
					val += current_point.x
				var p := Vector2(val, current_point.y)
				subpath_points.append(p)
				current_point = p
				last_command = active_cmd
				
			"V", "v":
				if idx >= tokens.size():
					break
				var val = tokens[idx]
				idx += 1
				if active_cmd == "v":
					val += current_point.y
				var p := Vector2(current_point.x, val)
				subpath_points.append(p)
				current_point = p
				last_command = active_cmd
				
			"C", "c":
				if idx + 5 >= tokens.size():
					break
				var p1 := Vector2(tokens[idx], tokens[idx+1])
				var p2 := Vector2(tokens[idx+2], tokens[idx+3])
				var p3 := Vector2(tokens[idx+4], tokens[idx+5])
				idx += 6
				if active_cmd == "c":
					p1 += current_point
					p2 += current_point
					p3 += current_point
					
				for step in range(1, 9):
					var t = step / 8.0
					var pt = evaluate_cubic_bezier(current_point, p1, p2, p3, t)
					subpath_points.append(pt)
				current_point = p3
				last_control_point = p2
				last_command = active_cmd
				
			"S", "s":
				if idx + 3 >= tokens.size():
					break
				var p2 := Vector2(tokens[idx], tokens[idx+1])
				var p3 := Vector2(tokens[idx+2], tokens[idx+3])
				idx += 4
				if active_cmd == "s":
					p2 += current_point
					p3 += current_point
					
				var p1: Vector2
				if last_command == "C" or last_command == "c" or last_command == "S" or last_command == "s":
					p1 = 2.0 * current_point - last_control_point
				else:
					p1 = current_point
					
				for step in range(1, 9):
					var t = step / 8.0
					var pt = evaluate_cubic_bezier(current_point, p1, p2, p3, t)
					subpath_points.append(pt)
				current_point = p3
				last_control_point = p2
				last_command = active_cmd
				
			"Q", "q":
				if idx + 3 >= tokens.size():
					break
				var p1 := Vector2(tokens[idx], tokens[idx+1])
				var p2 := Vector2(tokens[idx+2], tokens[idx+3])
				idx += 4
				if active_cmd == "q":
					p1 += current_point
					p2 += current_point
					
				for step in range(1, 9):
					var t = step / 8.0
					var pt = evaluate_quadratic_bezier(current_point, p1, p2, t)
					subpath_points.append(pt)
				current_point = p2
				last_control_point = p1
				last_command = active_cmd
				
			"T", "t":
				if idx + 1 >= tokens.size():
					break
				var p2 := Vector2(tokens[idx], tokens[idx+1])
				idx += 2
				if active_cmd == "t":
					p2 += current_point
					
				var p1: Vector2
				if last_command == "Q" or last_command == "q" or last_command == "T" or last_command == "t":
					p1 = 2.0 * current_point - last_control_point
				else:
					p1 = current_point
					
				for step in range(1, 9):
					var t = step / 8.0
					var pt = evaluate_quadratic_bezier(current_point, p1, p2, t)
					subpath_points.append(pt)
				current_point = p2
				last_control_point = p1
				last_command = active_cmd
				
			"Z", "z":
				if subpath_points.size() > 0:
					if current_point != start_point:
						subpath_points.append(start_point)
					var cmd = create_draw_command(DrawCommand.Type.PRECISE_PATH, subpath_points, false, state)
					commands.append(cmd)
					subpath_points = PackedVector2Array()
				current_point = start_point
				last_command = active_cmd
				
			_:
				if active_cmd == "A" or active_cmd == "a":
					if idx + 6 >= tokens.size():
						break
					var end_p := Vector2(tokens[idx+5], tokens[idx+6])
					idx += 7
					if active_cmd == "a":
						end_p += current_point
					subpath_points.append(end_p)
					current_point = end_p
					last_command = active_cmd
				else:
					break
					
	if subpath_points.size() > 0:
		var cmd = create_draw_command(DrawCommand.Type.PRECISE_PATH, subpath_points, true, state)
		commands.append(cmd)
		
	return commands

# Parses an SVG string content into a dictionary of: { "bounds": Vector2i, "commands": Array[DrawCommand] }
static func svg_to_commands_and_bounds(svg_content: String) -> Dictionary:
	var parser := XMLParser.new()
	var err := parser.open_buffer(svg_content.to_utf8_buffer())
	if err != OK:
		push_error("Failed to open XML buffer")
		return {}
		
	var bounds := Vector2i(144, 168)
	var commands: Array[DrawCommand] = []
	
	# State stack containing styling and transforms inheritance context
	var state_stack: Array[Dictionary] = []
	var current_state := {
		"transform": Transform2D.IDENTITY,
		"style": {
			"fill": Color.BLACK,
			"stroke": Color(0, 0, 0, 0),
			"stroke_width": 1,
			"opacity": 1.0,
			"fill_opacity": 1.0,
			"stroke_opacity": 1.0
		}
	}
	
	while parser.read() == OK:
		var type = parser.get_node_type()
		match type:
			XMLParser.NODE_ELEMENT:
				var tag = parser.get_node_name().to_lower()
				var attributes = {}
				for a in range(parser.get_attribute_count()):
					attributes[parser.get_attribute_name(a)] = parser.get_attribute_value(a)
				
				# Local transform accumulation
				var local_transform := Transform2D.IDENTITY
				if attributes.has("transform"):
					local_transform = parse_transform(attributes["transform"])
				var node_transform = current_state["transform"] * local_transform
				
				# Style accumulation
				var node_style = current_state["style"].duplicate()
				node_style = parse_style_attributes(attributes, node_style)
				
				state_stack.push_back(current_state)
				current_state = {
					"transform": node_transform,
					"style": node_style
				}
				
				match tag:
					"svg":
						if attributes.has("viewBox"):
							var vb_regex = RegEx.new()
							vb_regex.compile("([-\\d.]+)")
							var vb_matches = vb_regex.search_all(attributes["viewBox"])
							if vb_matches.size() >= 4:
								bounds.x = roundi(vb_matches[2].get_string(0).to_float())
								bounds.y = roundi(vb_matches[3].get_string(0).to_float())
						elif attributes.has("width") and attributes.has("height"):
							bounds.x = roundi(attributes["width"].to_float())
							bounds.y = roundi(attributes["height"].to_float())
					"path":
						if attributes.has("d"):
							var path_cmds = parse_svg_path(attributes["d"], current_state)
							commands.append_array(path_cmds)
					"rect":
						var w = attributes.get("width", "0").to_float()
						var h = attributes.get("height", "0").to_float()
						if w > 0 and h > 0:
							var x = attributes.get("x", "0").to_float()
							var y = attributes.get("y", "0").to_float()
							var pts = PackedVector2Array([
								Vector2(x, y),
								Vector2(x + w, y),
								Vector2(x + w, y + h),
								Vector2(x, y + h)
							])
							var cmd = create_draw_command(DrawCommand.Type.PRECISE_PATH, pts, false, current_state)
							commands.append(cmd)
					"circle":
						var r = attributes.get("r", "0").to_float()
						if r > 0:
							var cx = attributes.get("cx", "0").to_float()
							var cy = attributes.get("cy", "0").to_float()
							var center = current_state["transform"] * Vector2(cx, cy)
							var scale_factor = (current_state["transform"].basis_xport(Vector2(r, 0))).length()
							var cmd = DrawCommand.new()
							cmd.draw_type = DrawCommand.Type.CIRCLE
							cmd.circle_radius = roundi(scale_factor)
							cmd.points = PackedVector2Array([center])
							apply_command_styles(cmd, current_state["style"])
							commands.append(cmd)
					"line":
						var x1 = attributes.get("x1", "0").to_float()
						var y1 = attributes.get("y1", "0").to_float()
						var x2 = attributes.get("x2", "0").to_float()
						var y2 = attributes.get("y2", "0").to_float()
						var pts = PackedVector2Array([Vector2(x1, y1), Vector2(x2, y2)])
						var cmd = create_draw_command(DrawCommand.Type.PRECISE_PATH, pts, true, current_state)
						commands.append(cmd)
					"polyline":
						if attributes.has("points"):
							var pts = parse_points_attribute(attributes["points"])
							if pts.size() > 0:
								var cmd = create_draw_command(DrawCommand.Type.PRECISE_PATH, pts, true, current_state)
								commands.append(cmd)
					"polygon":
						if attributes.has("points"):
							var pts = parse_points_attribute(attributes["points"])
							if pts.size() > 0:
								var cmd = create_draw_command(DrawCommand.Type.PRECISE_PATH, pts, false, current_state)
								commands.append(cmd)
				
				# Empty tags like <rect /> do not generate NODE_ELEMENT_END, pop early
				if parser.is_empty():
					current_state = state_stack.pop_back()
					
			XMLParser.NODE_ELEMENT_END:
				if state_stack.size() > 0:
					current_state = state_stack.pop_back()
	
	return {"bounds": bounds, "commands": commands}

# Converts SVG text into a DrawCommandSequence
static func svg_to_sequence(svg_content: String) -> DrawCommandSequence:
	var res = svg_to_commands_and_bounds(svg_content)
	if res.is_empty():
		return null
	var seq = DrawCommandSequence.new()
	var image = DrawCommandImage.new()
	image.bounds = res["bounds"]
	image.commands = res["commands"]
	seq.frames.append(image)
	seq.frame_durations_ms.append(100) # Default duration
	return seq

# Converts multiple SVG contents into a single animated DrawCommandSequence
static func svg_files_to_sequence(svg_contents: Array[String], durations: Array[int] = []) -> DrawCommandSequence:
	var sequence = DrawCommandSequence.new()
	var first = true
	var bounds = Vector2i(144, 168)
	for i in range(svg_contents.size()):
		var res = svg_to_commands_and_bounds(svg_contents[i])
		if res.is_empty():
			continue
		if first:
			bounds = res["bounds"]
			first = false
		var image = DrawCommandImage.new()
		image.bounds = bounds
		image.commands = res["commands"]
		sequence.frames.append(image)
		var dur = durations[i] if i < durations.size() else 100
		sequence.frame_durations_ms.append(dur)
	return sequence

# Serializes style properties of DrawCommand into SVG attribute strings
static func color_to_svg_attrs(color: Color, prefix: String) -> String:
	if color.a == 0:
		return '%s="none"' % prefix
	var hex = color.to_html(false)
	var attrs = '%s="#%s"' % [prefix, hex]
	if color.a < 1.0:
		attrs += ' %s-opacity="%f"' % [prefix, color.a]
	return attrs

# Serializes a list of DrawCommands into SVG nodes inside an XML template
static func serialize_commands_to_svg(commands: Array[DrawCommand]) -> String:
	var xml = ""
	for cmd in commands:
		if cmd.hidden:
			continue
		var stroke_attrs = color_to_svg_attrs(cmd.stroke_color, "stroke")
		if not cmd.stroke_color.a == 0:
			stroke_attrs += ' stroke-width="%d"' % cmd.stroke_width
		var fill_attrs = color_to_svg_attrs(cmd.fill_color, "fill")
		
		if cmd.draw_type == DrawCommand.Type.CIRCLE:
			if cmd.points.size() > 0:
				var center = cmd.points[0]
				xml += '  <circle cx="%f" cy="%f" r="%d" %s %s />\n' % [
					center.x, center.y, cmd.circle_radius, stroke_attrs, fill_attrs
				]
		elif cmd.draw_type == DrawCommand.Type.PATH or cmd.draw_type == DrawCommand.Type.PRECISE_PATH:
			if cmd.points.size() >= 2:
				var d_path = "M %f %f" % [cmd.points[0].x, cmd.points[0].y]
				for k in range(1, cmd.points.size()):
					d_path += " L %f %f" % [cmd.points[k].x, cmd.points[k].y]
				if not cmd.path_open:
					d_path += " Z"
				xml += '  <path d="%s" %s %s />\n' % [d_path, stroke_attrs, fill_attrs]
	return xml

# Exports a specific frame in the sequence to a static SVG string
static func frame_to_svg(sequence: DrawCommandSequence, frame_idx: int) -> String:
	if sequence == null or sequence.frames.is_empty():
		return ""
	var idx = clampi(frame_idx, 0, sequence.frames.size() - 1)
	var frame = sequence.frames[idx]
	var w = frame.bounds.x
	var h = frame.bounds.y
	
	var svg = '<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n'
	svg += '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">\n' % [w, h, w, h]
	svg += serialize_commands_to_svg(frame.commands)
	svg += '</svg>\n'
	return svg

# Exports the sequence as a single animated SVG using show/hide CSS rules
static func sequence_to_animated_svg(sequence: DrawCommandSequence) -> String:
	if sequence == null or sequence.frames.is_empty():
		return ""
	var first_frame = sequence.frames[0]
	var w = first_frame.bounds.x
	var h = first_frame.bounds.y
	
	var total_duration = 0
	for d in sequence.frame_durations_ms:
		total_duration += d
	if total_duration <= 0:
		total_duration = sequence.frames.size() * 100
		
	var total_s = total_duration / 1000.0
	
	var svg = '<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n'
	svg += '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">\n' % [w, h, w, h]
	svg += '  <style>\n'
	svg += '    .animated-frame {\n'
	svg += '      visibility: hidden;\n'
	svg += '      animation-duration: %fs;\n' % total_s
	svg += '      animation-iteration-count: infinite;\n'
	svg += '      animation-fill-mode: forwards;\n'
	svg += '    }\n'
	
	var current_ms = 0
	for i in range(sequence.frames.size()):
		var dur = sequence.frame_durations_ms[i] if i < sequence.frame_durations_ms.size() else 100
		if dur <= 0:
			dur = 100
		var start_pct = (current_ms * 100.0) / total_duration
		var end_pct = ((current_ms + dur) * 100.0) / total_duration
		current_ms += dur
		
		svg += '    #frame_%d {\n' % i
		svg += '      animation-name: frame-show-%d;\n' % i
		svg += '    }\n'
		svg += '    @keyframes frame-show-%d {\n' % i
		if start_pct > 0.0:
			svg += '      0%% { visibility: hidden; }\n'
			svg += '      %.4f%% { visibility: hidden; }\n' % start_pct
		svg += '      %.4f%% { visibility: visible; }\n' % start_pct
		svg += '      %.4f%% { visibility: visible; }\n' % end_pct
		if end_pct < 100.0:
			svg += '      %.4f%% { visibility: hidden; }\n' % end_pct
			svg += '      100%% { visibility: hidden; }\n'
		svg += '    }\n'
		
	svg += '  </style>\n'
	
	# Generate frame layers
	for i in range(sequence.frames.size()):
		svg += '  <g id="frame_%d" class="animated-frame">\n' % i
		svg += serialize_commands_to_svg(sequence.frames[i].commands)
		svg += '  </g>\n'
		
	svg += '</svg>\n'
	return svg
