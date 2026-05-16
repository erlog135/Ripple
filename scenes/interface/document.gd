extends Node2D

var _vector_canvas: Node2D
var _raster_sprite: Sprite2D

func _ready() -> void:
	_vector_canvas = Node2D.new()
	_vector_canvas.name = "VectorCanvas"
	add_child(_vector_canvas)

	_raster_sprite = Sprite2D.new()
	_raster_sprite.name = "RasterSprite"
	_raster_sprite.centered = false
	_raster_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_raster_sprite)

	_apply_render_mode()

	ProjectData.data_changed.connect(_on_data_changed)
	EditorState.current_frame_changed.connect(_on_current_frame_changed)
	EditorState.drag_updated.connect(_on_drag_updated)
	EditorState.render_mode_changed.connect(_on_render_mode_changed)
	RenderManager.preview_updated.connect(_on_preview_updated)
	_render_current_image()

func _on_data_changed(_by_user: bool) -> void:
	_render_current_image()

func _on_current_frame_changed(_frame: int) -> void:
	_render_current_image()

func _on_drag_updated(_offset: Vector2, _dragging: bool) -> void:
	_render_current_image()

func _on_render_mode_changed(_mode: EditorState.RenderMode) -> void:
	_apply_render_mode()
	_render_current_image()

func _on_preview_updated() -> void:
	if EditorState.render_mode == EditorState.RenderMode.RASTER:
		_render_raster()

func _apply_render_mode() -> void:
	var is_raster := EditorState.render_mode == EditorState.RenderMode.RASTER
	_vector_canvas.visible = not is_raster
	_raster_sprite.visible = is_raster

func _render_current_image() -> void:
	match EditorState.render_mode:
		EditorState.RenderMode.VECTOR:
			_render_vector()
		EditorState.RenderMode.RASTER:
			_render_raster()

func _render_vector() -> void:
	for child in _vector_canvas.get_children():
		child.queue_free()

	var image: DrawCommandImage = ProjectData.get_current_image()
	if image == null:
		return

	for cmd_idx in range(image.commands.size()):
		_draw_command(image.commands[cmd_idx], cmd_idx)

func _render_raster() -> void:
	_raster_sprite.texture = RenderManager.get_frame_texture(EditorState.current_frame)

func _draw_command(cmd: DrawCommand, cmd_idx: int) -> void:
	if cmd.hidden:
		return

	var points := _points_with_drag_offset(cmd.points, cmd_idx)

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

func _points_with_drag_offset(points: PackedVector2Array, cmd_idx: int) -> PackedVector2Array:
	if not EditorState.is_dragging_selection or EditorState.drag_offset == Vector2.ZERO:
		return points

	var selected_pts: Array = EditorState.selected_point_indices.get(cmd_idx, [])
	if selected_pts.is_empty():
		return points

	var shifted: PackedVector2Array = points.duplicate()
	for pt_idx in selected_pts:
		if pt_idx >= 0 and pt_idx < shifted.size():
			shifted[pt_idx] += EditorState.drag_offset
	return shifted

func _circle_points(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var angle := i * TAU / 16
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts
