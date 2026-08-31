extends Node2D

var _vector_canvas: Node2D
var _onion_prev_canvas: Node2D
var _onion_next_canvas: Node2D

var _raster_sprite: Sprite2D
var _onion_prev_sprite: Sprite2D
var _onion_next_sprite: Sprite2D

func _ready() -> void:
	_vector_canvas = Node2D.new()
	_vector_canvas.name = "VectorCanvas"
	add_child(_vector_canvas)

	_onion_prev_canvas = Node2D.new()
	_onion_prev_canvas.name = "OnionPrevCanvas"
	_onion_prev_canvas.modulate = Color(1.0, 1.0, 1.0, 0.3)
	add_child(_onion_prev_canvas)

	_onion_next_canvas = Node2D.new()
	_onion_next_canvas.name = "OnionNextCanvas"
	_onion_next_canvas.modulate = Color(1.0, 1.0, 1.0, 0.3)
	add_child(_onion_next_canvas)


	_raster_sprite = Sprite2D.new()
	_raster_sprite.name = "RasterSprite"
	_raster_sprite.centered = false
	_raster_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_raster_sprite)

	_onion_prev_sprite = Sprite2D.new()
	_onion_prev_sprite.name = "OnionPrevSprite"
	_onion_prev_sprite.centered = false
	_onion_prev_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_onion_prev_sprite.modulate = Color(1.0, 1.0, 1.0, 0.3)
	add_child(_onion_prev_sprite)

	_onion_next_sprite = Sprite2D.new()
	_onion_next_sprite.name = "OnionNextSprite"
	_onion_next_sprite.centered = false
	_onion_next_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_onion_next_sprite.modulate = Color(1.0, 1.0, 1.0, 0.3)
	add_child(_onion_next_sprite)


	_apply_render_mode()

	ProjectData.data_changed.connect(_on_data_changed)
	EditorState.current_frame_changed.connect(_on_current_frame_changed)
	EditorState.transform_preview_changed.connect(_on_transform_preview_changed)
	EditorState.render_mode_changed.connect(_on_render_mode_changed)
	EditorState.onion_skin_changed.connect(_on_onion_skin_changed)
	EditorState.playback_state_changed.connect(_on_playback_state_changed)
	RenderManager.preview_updated.connect(_on_preview_updated)
	_render_current_image()

func _on_data_changed(_by_user: bool, _affected_frame: int) -> void:
	_render_current_image()

func _on_current_frame_changed(_frame: int) -> void:
	_render_current_image()

func _on_transform_preview_changed() -> void:
	_render_current_image()

func _on_render_mode_changed(_mode: EditorState.RenderMode) -> void:
	_apply_render_mode()
	_render_current_image()

func _on_onion_skin_changed(_enabled: bool) -> void:
	_apply_render_mode()
	_render_current_image()

func _on_playback_state_changed(_playing: bool) -> void:
	_apply_render_mode()
	_render_current_image()

func _on_preview_updated() -> void:
	if EditorState.render_mode == EditorState.RenderMode.RASTER:
		_render_raster()

func _apply_render_mode() -> void:
	var is_raster := EditorState.render_mode == EditorState.RenderMode.RASTER
	var onion_visible := EditorState.onion_skin_enabled and not EditorState.is_playing
	
	_vector_canvas.visible = not is_raster
	_onion_prev_canvas.visible = not is_raster and onion_visible
	_onion_next_canvas.visible = not is_raster and onion_visible

	_raster_sprite.visible = is_raster
	_onion_prev_sprite.visible = is_raster and onion_visible
	_onion_next_sprite.visible = is_raster and onion_visible

func _render_current_image() -> void:
	match EditorState.render_mode:
		EditorState.RenderMode.VECTOR:
			_render_vector()
		EditorState.RenderMode.RASTER:
			_render_raster()

func _render_vector() -> void:
	for child in _vector_canvas.get_children():
		child.queue_free()
	for child in _onion_prev_canvas.get_children():
		child.queue_free()
	for child in _onion_next_canvas.get_children():
		child.queue_free()

	var seq := ProjectData.current_sequence
	if seq == null:
		return

	var current_idx := EditorState.current_frame

	# Render Onion Skins
	if EditorState.onion_skin_enabled and not EditorState.is_playing:
		if current_idx - 1 >= 0 and current_idx - 1 < seq.frames.size():
			var prev_image := seq.frames[current_idx - 1]
			for cmd_idx in range(prev_image.commands.size()):
				_draw_command_to_canvas(prev_image.commands[cmd_idx], cmd_idx, _onion_prev_canvas, false)

		if current_idx + 1 >= 0 and current_idx + 1 < seq.frames.size():
			var next_image := seq.frames[current_idx + 1]
			for cmd_idx in range(next_image.commands.size()):
				_draw_command_to_canvas(next_image.commands[cmd_idx], cmd_idx, _onion_next_canvas, false)

	var image: DrawCommandImage = seq.frames[current_idx] if current_idx >= 0 and current_idx < seq.frames.size() else null
	if image == null:
		return

	for cmd_idx in range(image.commands.size()):
		_draw_command_to_canvas(image.commands[cmd_idx], cmd_idx, _vector_canvas, true)

func _render_raster() -> void:
	var current_idx := EditorState.current_frame
	_raster_sprite.texture = RenderManager.get_frame_texture(current_idx)
	_raster_sprite.position = RenderManager.get_preview_raster_origin().round()

	var seq := ProjectData.current_sequence
	if seq == null:
		_onion_prev_sprite.texture = null
		_onion_next_sprite.texture = null
		return

	if EditorState.onion_skin_enabled and not EditorState.is_playing:
		if current_idx - 1 >= 0 and current_idx - 1 < seq.frames.size():
			_onion_prev_sprite.texture = RenderManager.get_frame_texture(current_idx - 1)
			_onion_prev_sprite.position = RenderManager.get_preview_raster_origin().round()
		else:
			_onion_prev_sprite.texture = null
			
		if current_idx + 1 >= 0 and current_idx + 1 < seq.frames.size():
			_onion_next_sprite.texture = RenderManager.get_frame_texture(current_idx + 1)
			_onion_next_sprite.position = RenderManager.get_preview_raster_origin().round()
		else:
			_onion_next_sprite.texture = null
	else:
		_onion_prev_sprite.texture = null
		_onion_next_sprite.texture = null

func _draw_command_to_canvas(cmd: DrawCommand, cmd_idx: int, canvas: Node2D, apply_drag_offset: bool) -> void:
	if cmd.hidden:
		return

	var points := _points_with_drag_offset(cmd.points, cmd_idx) if apply_drag_offset else cmd.points

	if cmd.draw_type == DrawCommand.Type.CIRCLE and points.size() > 0:
		var radius := float(cmd.circle_radius)
		if apply_drag_offset and EditorState.is_transform_previewing() and EditorState.transform_mode == EditorState.TransformMode.SCALE and EditorState.transform_matrix != Transform2D.IDENTITY:
			var m := EditorState.transform_matrix
			var radius_scale := (m.x.length() + m.y.length()) / 2.0
			radius = maxf(1.0, radius * radius_scale)
		points = _circle_points(points[0], radius)

	if cmd.fill_color.a > 0:
		var poly := Polygon2D.new()
		poly.polygon = points
		poly.color = cmd.fill_color
		poly.antialiased = true
		canvas.add_child(poly)

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
		canvas.add_child(line)

func _points_with_drag_offset(points: PackedVector2Array, cmd_idx: int) -> PackedVector2Array:
	if not EditorState.is_transform_previewing() or EditorState.transform_matrix == Transform2D.IDENTITY:
		return points

	var selected_pts: Array = EditorState.selected_point_indices.get(cmd_idx, [])
	if selected_pts.is_empty():
		return points

	var frame: DrawCommandImage = ProjectData.get_current_image() if EditorState.grid_snap else null
	var cmd: DrawCommand = frame.commands[cmd_idx] if (frame != null and cmd_idx < frame.commands.size()) else null
	var shifted: PackedVector2Array = points.duplicate()
	for pt_idx in selected_pts:
		if pt_idx >= 0 and pt_idx < shifted.size():
			var transformed := EditorState.transform_matrix * shifted[pt_idx]
			if cmd != null:
				transformed = EditorState.snap_world_position(
					transformed, cmd.draw_type, cmd.stroke_width
				)
			shifted[pt_idx] = transformed
	return shifted

func _circle_points(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var angle := i * TAU / 16
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts
