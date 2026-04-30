extends Node2D

var _vector_canvas: Node2D

func _ready() -> void:
	_vector_canvas = Node2D.new()
	_vector_canvas.name = "VectorCanvas"
	add_child(_vector_canvas)

	ProjectData.data_changed.connect(_on_data_changed)
	_render_sequence(ProjectData.current_sequence)

func _on_data_changed(_by_user: bool) -> void:
	_render_sequence(ProjectData.current_sequence)

func _render_sequence(sequence: DrawCommandSequence) -> void:
	for child in _vector_canvas.get_children():
		child.queue_free()

	if sequence == null or sequence.frames.is_empty():
		return

	var image: DrawCommandImage = sequence.frames[0]
	for cmd in image.commands:
		_draw_command(cmd)

func _draw_command(cmd: DrawCommand) -> void:
	if cmd.hidden:
		return

	var points := cmd.points

	if cmd.draw_type == DrawCommand.Type.CIRCLE and points.size() > 0:
		points = _circle_points(points[0], cmd.circle_radius)

	if cmd.fill_color.a > 0:
		var poly := Polygon2D.new()
		poly.polygon = points
		poly.color = cmd.fill_color
		poly.antialiased = true
		_vector_canvas.add_child(poly)

	if cmd.stroke_color.a > 0 and cmd.stroke_width > 0:
		var line := Line2D.new()
		if cmd.draw_type == DrawCommand.Type.CIRCLE or not cmd.path_open:
			var closed := points.duplicate()
			if closed.size() > 0:
				closed.append(closed[0])
			line.points = closed
		else:
			line.points = points
		line.default_color = cmd.stroke_color
		line.width = cmd.stroke_width
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		_vector_canvas.add_child(line)

func _circle_points(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var angle := i * TAU / 16
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts
