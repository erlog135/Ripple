@tool
extends Node2D
class_name PDCVisualizer

@export var frame_index: int = 0:
	set(value):
		frame_index = value
		if is_inside_tree():
			_draw_frame()

@export var pixelated: bool = false:
	set(value):
		pixelated = value
		_update_pixelation_state()

var sequence: DrawCommandSequence = null:
	set(value):
		sequence = value
		if is_inside_tree():
			_draw_frame()

var _vector_canvas: Node2D
var _viewport: SubViewport
var _sprite: Sprite2D
var _is_setup := false

func _ready():
	_setup_nodes()
	_draw_frame()

func _setup_nodes():
	if _is_setup: return

	for child in get_children():
		child.queue_free()

	_vector_canvas = Node2D.new()
	_vector_canvas.name = "VectorCanvas"

	_viewport = SubViewport.new()
	_viewport.name = "PixelViewport"
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_sprite = Sprite2D.new()
	_sprite.name = "PixelSprite"
	# Chunky retro pixels instead of blurry blocks
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false

	add_child(_viewport)
	add_child(_sprite)
	add_child(_vector_canvas)

	_sprite.visible = false
	_sprite.texture = _viewport.get_texture()

	_is_setup = true
	_update_pixelation_state()

func _update_pixelation_state():
	if not _is_setup: return

	if pixelated:
		if _vector_canvas.get_parent() == self:
			remove_child(_vector_canvas)
			_viewport.add_child(_vector_canvas)
		_sprite.visible = true
	else:
		if _vector_canvas.get_parent() == _viewport:
			_viewport.remove_child(_vector_canvas)
			add_child(_vector_canvas)
		_sprite.visible = false

## Convenience method to set both sequence and frame at once.
func display(seq: DrawCommandSequence, frame_idx: int = 0) -> void:
	sequence = seq
	frame_index = frame_idx

func _draw_frame() -> void:
	if not _is_setup:
		return

	for child in _vector_canvas.get_children():
		child.queue_free()

	if sequence == null or sequence.frames.is_empty():
		return

	var idx = clampi(frame_index, 0, sequence.frames.size() - 1)
	var image: DrawCommandImage = sequence.frames[idx]

	_viewport.size = image.bounds

	for cmd in image.commands:
		_draw_command(cmd)

func _draw_command(cmd: DrawCommand) -> void:
	if cmd.hidden:
		return

	var points := cmd.points

	if cmd.draw_type == DrawCommand.type.CIRCLE and points.size() > 0:
		points = _circle_points(points[0], cmd.circle_radius)

	if cmd.fill_color.a > 0:
		var poly := Polygon2D.new()
		poly.polygon = points
		poly.color = cmd.fill_color
		poly.antialiased = true
		_vector_canvas.add_child(poly)

	if cmd.stroke_color.a > 0 and cmd.stroke_width > 0:
		var line := Line2D.new()
		if cmd.draw_type == DrawCommand.type.CIRCLE or not cmd.path_open:
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
		var angle = i * TAU / 16
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts
