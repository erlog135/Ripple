class_name Rasterizer

const BYTES_PER_PIXEL := 4  # RGBA8

func render(image_data: DrawCommandImage) -> ImageTexture:
	var w := image_data.bounds.x
	var h := image_data.bounds.y
	if w <= 0 or h <= 0:
		return null

	var framebuffer := PackedByteArray()
	framebuffer.resize(w * h * BYTES_PER_PIXEL)
	framebuffer.fill(0xFF)  # Opaque white background

	# PebbleOS uses an 8x8 subpixel grid for precise coordinates and anti-aliasing
	var w8 := w * 8
	var h8 := h * 8
	var subpixel_grid := PackedByteArray()
	subpixel_grid.resize(w8 * h8)

	for cmd in image_data.commands:
		if cmd.hidden:
			continue

		var points := cmd.points
		if cmd.draw_type == DrawCommand.Type.CIRCLE and points.size() > 0:
			points = _circle_points_16gon(points[0], cmd.circle_radius)

		# --- Filling Phase ---
		if cmd.fill_color.a > 0:
			subpixel_grid.fill(0)
			_rasterize_polygon(points, w8, h8, subpixel_grid)
			
			var bounds := _get_bounds(points, w, h, 1)
			_apply_subpixels_and_blend(framebuffer, bounds, w, h, subpixel_grid, cmd.fill_color)

		# --- Stroking Phase ---
		if cmd.stroke_color.a > 0 and cmd.stroke_width > 0:
			subpixel_grid.fill(0)
			
			var stroke_points := PackedVector2Array(points)
			if cmd.draw_type == DrawCommand.Type.CIRCLE or not cmd.path_open:
				if stroke_points.size() > 0:
					stroke_points.append(stroke_points[0]) # Close path
					
			var hw := cmd.stroke_width / 2.0
			
			# Generate Line Segments (Rectangles)
			for i in range(stroke_points.size() - 1):
				var p1 := stroke_points[i]
				var p2 := stroke_points[i+1]
				if p1.distance_to(p2) > 0.001:
					var rect := _get_thick_line_rect(p1, p2, cmd.stroke_width)
					_rasterize_polygon(rect, w8, h8, subpixel_grid)
					
			# Generate Round Caps and Joints (Treated as anchored filled circles)
			for pt in stroke_points:
				var cap := _circle_points_16gon(pt, hw)
				_rasterize_polygon(cap, w8, h8, subpixel_grid)
			
			var bounds := _get_bounds(points, w, h, int(ceil(hw)) + 1)
			_apply_subpixels_and_blend(framebuffer, bounds, w, h, subpixel_grid, cmd.stroke_color)

	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, framebuffer)
	return ImageTexture.create_from_image(img)

# -------------------------------------------------------------------------
# Subpixel Rendering Engine (Scanline & Even-Odd Winding)
# -------------------------------------------------------------------------

func _rasterize_polygon(points: PackedVector2Array, w8: int, h8: int, subpixel_grid: PackedByteArray) -> void:
	if points.size() < 3:
		return
		
	var edges := []
	for i in range(points.size()):
		var p1 := points[i]
		var p2 := points[(i + 1) % points.size()]
		
		# Convert float pixel coordinates directly to the fixed-point subpixel space
		var x1 := int(round(p1.x * 8.0))
		var y1 := int(round(p1.y * 8.0))
		var x2 := int(round(p2.x * 8.0))
		var y2 := int(round(p2.y * 8.0))

		if y1 == y2: 
			continue # Horizontal edges are discarded in scanline algorithms

		var ymin :int = min(y1, y2)
		var ymax :int = max(y1, y2)
		var x_at_ymin := float(x1) if y1 < y2 else float(x2)
		var dx_dy := float(x2 - x1) / float(y2 - y1)

		edges.append({
			"ymin": ymin,
			"ymax": ymax,
			"x": x_at_ymin,
			"dx": dx_dy
		})

	if edges.is_empty():
		return

	# Sort Edge Table (ET) by minimum Y
	edges.sort_custom(func(a, b): return a.ymin < b.ymin)

	var active_ymin: int = edges[0].ymin
	var active_ymax: int = edges[0].ymax
	for e in edges:
		if e.ymax > active_ymax: 
			active_ymax = e.ymax

	var aet := []
	var edge_idx := 0
	var num_edges := edges.size()

	for y in range(active_ymin, active_ymax):
		# Move edges from ET to AET
		while edge_idx < num_edges and edges[edge_idx].ymin == y:
			aet.append(edges[edge_idx].duplicate())
			edge_idx += 1

		# Remove exhausted edges
		for i in range(aet.size() - 1, -1, -1):
			if aet[i].ymax == y:
				aet.remove_at(i)

		# Sort AET by current X-intersection
		aet.sort_custom(func(a, b): return a.x < b.x)

		# Even-Odd filling convention
		if y >= 0 and y < h8:
			var row_offset := y * w8
			for i in range(0, aet.size() - 1, 2):
				var x_start := clampi(int(round(aet[i].x)), 0, w8)
				var x_end := clampi(int(round(aet[i+1].x)), 0, w8)
				# Setting bits unconditionally to 1 functions as a boolean union 
				# for overlapping components belonging to the same layer (caps/strokes)
				for x in range(x_start, x_end):
					subpixel_grid[row_offset + x] = 1

		# Step intersections forward
		for e in aet:
			e.x += e.dx


func _apply_subpixels_and_blend(fb: PackedByteArray, bounds: Rect2i, w: int, h: int, subpixel_grid: PackedByteArray, color: Color) -> void:
	var base_alpha := int(round(color.a * 3.0))
	if base_alpha == 0:
		return

	var src_r := int(round(color.r * 3.0))
	var src_g := int(round(color.g * 3.0))
	var src_b := int(round(color.b * 3.0))

	var w8 := w * 8

	for y in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for x in range(bounds.position.x, bounds.position.x + bounds.size.x):
			var count := 0
			var row_offset := y * 8 * w8 + x * 8
			
			# Count coverage mask in the 8x8 area
			for sy in range(8):
				var sub_idx := row_offset + sy * w8
				for sx in range(8):
					if subpixel_grid[sub_idx + sx] > 0:
						count += 1
						
			if count == 0:
				continue

			# PebbleOS Quantized Coverage Mapping to 2-Bit Alpha (0, 33%, 66%, 100%)
			var cov_alpha := 0
			if count >= 40:     # C >= 0.625
				cov_alpha = 3 
			elif count >= 24:   # C >= 0.375
				cov_alpha = 2
			elif count >= 8:    # C >= 0.125
				cov_alpha = 1

			if cov_alpha == 0:
				continue

			# Combine command alpha and coverage alpha via fixed-point math
			var final_alpha := (base_alpha * cov_alpha) / 3
			if final_alpha == 0:
				continue

			var px_idx := (y * w + x) * 4
			
			# Read 8-bit destination and scale down to 2-bit
			var dst_r := int(fb[px_idx]) / 85
			var dst_g := int(fb[px_idx+1]) / 85
			var dst_b := int(fb[px_idx+2]) / 85

			# PebbleOS blend logic: new = (src * alpha + dst * (3 - alpha)) / 3
			var out_r := ((src_r * final_alpha) + (dst_r * (3 - final_alpha))) / 3
			var out_g := ((src_g * final_alpha) + (dst_g * (3 - final_alpha))) / 3
			var out_b := ((src_b * final_alpha) + (dst_b * (3 - final_alpha))) / 3

			# Scale back to Godot 8-bit output
			fb[px_idx] = out_r * 85
			fb[px_idx+1] = out_g * 85
			fb[px_idx+2] = out_b * 85
			# Ensure alpha channel stays solid 255 for the output texture
			fb[px_idx+3] = 255

# -------------------------------------------------------------------------
# Vector Math & Geometric Primitives
# -------------------------------------------------------------------------

func _get_thick_line_rect(p1: Vector2, p2: Vector2, width: float) -> PackedVector2Array:
	var dir := (p2 - p1).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var offset := normal * (width / 2.0)
	
	return PackedVector2Array([
		p1 + offset,
		p1 - offset,
		p2 - offset,
		p2 + offset
	])

func _circle_points_16gon(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var angle := i * TAU / 16.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts

func _get_bounds(points: PackedVector2Array, w: int, h: int, expansion: int) -> Rect2i:
	if points.is_empty():
		return Rect2i(0, 0, 0, 0)
		
	var min_x := int(points[0].x)
	var max_x := min_x
	var min_y := int(points[0].y)
	var max_y := min_y

	for p in points:
		var px := int(p.x)
		var py := int(p.y)
		if px < min_x: min_x = px
		if px > max_x: max_x = px
		if py < min_y: min_y = py
		if py > max_y: max_y = py

	min_x = clampi(min_x - expansion, 0, w - 1)
	max_x = clampi(max_x + expansion, 0, w - 1)
	min_y = clampi(min_y - expansion, 0, h - 1)
	max_y = clampi(max_y + expansion, 0, h - 1)

	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)