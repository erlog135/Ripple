@tool
extends Node2D
class_name PDCVisualizer

@export_file("*.pdc") var pdc_file_path: String = "":
	set(value):
		pdc_file_path = value
		if is_inside_tree():
			_load_and_visualize()

@export var pixelated: bool = false:
	set(value):
		pixelated = value
		_update_pixelation_state()

var view_width: int = 144
var view_height: int = 168

var _vector_canvas: Node2D
var _viewport: SubViewport
var _sprite: Sprite2D
var _is_setup := false

func _ready():
	_setup_nodes()
	_load_and_visualize()

func _setup_nodes():
	if _is_setup: return
	
	# Clean up any editor-polluted children
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
	# This ensures it looks like chunky retro pixels instead of blurry blocks
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST 
	_sprite.centered = false
	
	add_child(_viewport)
	add_child(_sprite)
	add_child(_vector_canvas) # Default state (Vectors ON)
	
	_sprite.visible = false
	_sprite.texture = _viewport.get_texture()
	
	_is_setup = true
	_update_pixelation_state()

func _update_pixelation_state():
	if not _is_setup: return
	
	if pixelated:
		# Move the vectors into the low-res viewport
		if _vector_canvas.get_parent() == self:
			remove_child(_vector_canvas)
			_viewport.add_child(_vector_canvas)
		_sprite.visible = true
	else:
		# Return the vectors to the main high-res canvas
		if _vector_canvas.get_parent() == _viewport:
			_viewport.remove_child(_vector_canvas)
			add_child(_vector_canvas)
		_sprite.visible = false

func _load_and_visualize():
	if not _is_setup: return
	
	# Clear previous shapes
	for child in _vector_canvas.get_children():
		child.queue_free()
		
	if pdc_file_path == "" or not FileAccess.file_exists(pdc_file_path):
		return
		
	var file = FileAccess.open(pdc_file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open PDC file.")
		return
		
	file.set_big_endian(false)
	var magic = file.get_buffer(4).get_string_from_ascii()
	file.get_32() # Ignore size
	
	if magic == "PDCI":
		_parse_image(file)
	elif magic == "PDCS":
		_parse_sequence(file)
		
	# Force the viewport to match the exact dimensions of the PDC file
	_viewport.size = Vector2i(view_width, view_height)

func _parse_image(file: FileAccess):
	file.get_8() # Version
	file.get_8() # Reserved
	view_width = _read_int16(file)
	view_height = _read_int16(file)
	_parse_command_list(file)
	
func _parse_sequence(file: FileAccess):
	file.get_8() # Version
	file.get_8() # Reserved
	view_width = _read_int16(file)
	view_height = _read_int16(file)
	file.get_16() # Play count
	var frame_count = file.get_16()
	
	if frame_count > 0:
		file.get_16() # Duration
		_parse_command_list(file)

func _parse_command_list(file: FileAccess):
	var num_commands = file.get_16()
	for i in range(num_commands):
		_parse_command(file)

func _parse_command(file: FileAccess):
	var type = file.get_8()
	var flags = file.get_8()
	var stroke_color_val = file.get_8()
	var stroke_width = file.get_8()
	var fill_color_val = file.get_8()
	var path_open_or_radius = file.get_16()
	var num_points = file.get_16()
	
	var points = PackedVector2Array()
	for i in range(num_points):
		var x = _read_int16(file)
		var y = _read_int16(file)
		if type == 3: points.append(Vector2(x / 8.0, y / 8.0))
		else: points.append(Vector2(x, y))
			
	var hidden = (flags & 1) != 0
	if hidden: return
		
	var stroke_color = _parse_pebble_color(stroke_color_val)
	var fill_color = _parse_pebble_color(fill_color_val)
	
	if type == 2 and num_points > 0:
		points = _generate_circle_points(points[0], path_open_or_radius)
			
	if fill_color.a > 0:
		var poly = Polygon2D.new()
		poly.polygon = points
		poly.color = fill_color
		poly.antialiased = true
		_vector_canvas.add_child(poly)
		
	if stroke_color.a > 0 and stroke_width > 0:
		var line = Line2D.new()
		var is_open = (path_open_or_radius & 1) != 0
		
		if type == 2 or (not is_open and points.size() > 0):
			var closed_points = points.duplicate()
			closed_points.append(points[0])
			line.points = closed_points
		else:
			line.points = points
				
		line.default_color = stroke_color
		line.width = stroke_width
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		_vector_canvas.add_child(line)

func _read_int16(file: FileAccess) -> int:
	var val = file.get_16()
	if val > 32767: val -= 65536
	return val

func _parse_pebble_color(val: int) -> Color:
	var a_val = (val >> 6) & 3
	var r_val = (val >> 4) & 3
	var g_val = (val >> 2) & 3
	var b_val = val & 3
	return Color(r_val / 3.0, g_val / 3.0, b_val / 3.0, a_val / 3.0)

func _generate_circle_points(center: Vector2, radius: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var segments = 16
	for i in range(segments):
		var angle = i * TAU / segments
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts
