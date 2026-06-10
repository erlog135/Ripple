class_name Rasterizer

const BYTES_PER_PIXEL := 4  # RGBA8
## Extra pixels around content extents when using a computed preview canvas.
const THUMBNAIL_PADDING: int = 4


func compute_sequence_preview_layout(frames: Array) -> Dictionary:
	if frames.is_empty():
		return {"size": Vector2i.ZERO, "origin": Vector2.ZERO}

	var g_min := Vector2(INF, INF)
	var g_max := Vector2(-INF, -INF)
	var any := false

	for frame in frames:
		if frame == null or not (frame is DrawCommandImage):
			continue
		var f: DrawCommandImage = frame
		any = true
		var combined := _frame_combined_document_rect(f)
		g_min.x = minf(g_min.x, combined.position.x)
		g_min.y = minf(g_min.y, combined.position.y)
		var c_end: Vector2 = combined.end
		g_max.x = maxf(g_max.x, c_end.x)
		g_max.y = maxf(g_max.y, c_end.y)

	if not any or g_max.x < g_min.x or g_max.y < g_min.y:
		return {"size": Vector2i.ZERO, "origin": Vector2.ZERO}

	# Integer world origin so texture pixels line up with the editor pixel grid (vector / gizmos).
	var origin := Vector2(
		float(floori(g_min.x) - THUMBNAIL_PADDING),
		float(floori(g_min.y) - THUMBNAIL_PADDING)
	)
	var end_x := ceili(g_max.x) + THUMBNAIL_PADDING
	var end_y := ceili(g_max.y) + THUMBNAIL_PADDING
	var w := maxi(1, end_x - int(origin.x))
	var h := maxi(1, end_y - int(origin.y))
	return {"size": Vector2i(w, h), "origin": origin}


## Declared PDC bounds unioned with all visible ink (fills + thick strokes) for one frame.
func _frame_combined_document_rect(f: DrawCommandImage) -> Rect2:
	var decl := Rect2(Vector2.ZERO, Vector2(f.bounds))
	var ink := _frame_ink_extents_rect(f)
	if ink.size.x <= 0.0 or ink.size.y <= 0.0:
		return decl
	return decl.merge(ink)


## Axis-aligned bounds of fill + stroke geometry, mirroring [method render] point resolution.
func _frame_ink_extents_rect(f: DrawCommandImage) -> Rect2:
	var has := false
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)

	for cmd: DrawCommand in f.commands:
		if cmd.hidden:
			continue

		var points := cmd.points
		if cmd.draw_type == DrawCommand.Type.CIRCLE and points.size() > 0:
			points = _circle_points_16gon(points[0], cmd.circle_radius)

		const FILL_MARGIN := 1.0

		if cmd.fill_color.a > 0 and points.size() > 0:
			has = true
			for p: Vector2 in points:
				mn.x = minf(mn.x, p.x - FILL_MARGIN)
				mn.y = minf(mn.y, p.y - FILL_MARGIN)
				mx.x = maxf(mx.x, p.x + FILL_MARGIN)
				mx.y = maxf(mx.y, p.y + FILL_MARGIN)

		if cmd.stroke_color.a > 0 and cmd.stroke_width > 0:
			has = true
			var stroke_pts := PackedVector2Array(points)
			if cmd.draw_type == DrawCommand.Type.CIRCLE or not cmd.path_open:
				if stroke_pts.size() > 0:
					stroke_pts.append(stroke_pts[0])
			var hw := cmd.stroke_width / 2.0
			var sw := float(cmd.stroke_width)
			for i: int in range(stroke_pts.size() - 1):
				var p1: Vector2 = stroke_pts[i]
				var p2: Vector2 = stroke_pts[i + 1]
				if p1.distance_to(p2) <= 0.001:
					continue
				var quad := _get_thick_line_rect(p1, p2, sw)
				for j in range(quad.size()):
					var pv: Vector2 = quad[j]
					mn.x = minf(mn.x, pv.x)
					mn.y = minf(mn.y, pv.y)
					mx.x = maxf(mx.x, pv.x)
					mx.y = maxf(mx.y, pv.y)
			for pt: Vector2 in stroke_pts:
				var cap := _circle_points_16gon(pt, hw)
				for j in range(cap.size()):
					var cv: Vector2 = cap[j]
					mn.x = minf(mn.x, cv.x)
					mn.y = minf(mn.y, cv.y)
					mx.x = maxf(mx.x, cv.x)
					mx.y = maxf(mx.y, cv.y)

	if not has:
		return Rect2()
	return Rect2(mn, mx - mn)


func render(
	image_data: DrawCommandImage,
	canvas_size: Vector2i = Vector2i.ZERO,
	raster_origin: Vector2 = Vector2.ZERO
) -> ImageTexture:
	var w := canvas_size.x if canvas_size.x > 0 else image_data.bounds.x
	var h := canvas_size.y if canvas_size.y > 0 else image_data.bounds.y
	if w <= 0 or h <= 0:
		return null

	var framebuffer := PackedByteArray()
	framebuffer.resize(w * h * BYTES_PER_PIXEL)
	framebuffer.fill(0xAA)  # light gray background

	# PebbleOS uses an 8x8 subpixel grid for precise coordinates and anti-aliasing
	var w8 := w * 8
	var h8 := h * 8
	var subpixel_grid := PackedByteArray()
	subpixel_grid.resize(w8 * h8)

	var origin := raster_origin

	for cmd in image_data.commands:
		if cmd.hidden:
			continue

		var points := cmd.points
		if cmd.draw_type == DrawCommand.Type.CIRCLE and points.size() > 0:
			points = _circle_points_16gon(points[0], cmd.circle_radius)

		if origin != Vector2.ZERO:
			points = _packed_translate(points, -origin)

		# --- Filling Phase ---
		if cmd.fill_color.a > 0:
			subpixel_grid.fill(0)
			_rasterize_polygon(points, w8, h8, subpixel_grid)
			
			var bounds := _get_vertex_bounds_float(points, w, h, 1)
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
			
			var bounds := _get_stroke_blend_bounds(stroke_points, cmd.stroke_width, w, h)
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

func _packed_translate(pts: PackedVector2Array, delta: Vector2) -> PackedVector2Array:
	if delta == Vector2.ZERO:
		return pts
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in range(pts.size()):
		out[i] = pts[i] + delta
	return out


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

## Pixels to visit when blending subpixel coverage into the framebuffer. Using [method int] on
## vertices was too tight vs. the scanline/raster output, which shifted strokes/fills down-right
## relative to vector editing; [method floor] / [method ceil] on float extents fixes that.
func _get_vertex_bounds_float(points: PackedVector2Array, w: int, h: int, expansion: int) -> Rect2i:
	if points.is_empty():
		return Rect2i(0, 0, 0, 0)
	var min_xf := points[0].x
	var max_xf := points[0].x
	var min_yf := points[0].y
	var max_yf := points[0].y
	for p: Vector2 in points:
		min_xf = minf(min_xf, p.x)
		max_xf = maxf(max_xf, p.x)
		min_yf = minf(min_yf, p.y)
		max_yf = maxf(max_yf, p.y)
	var ex := float(expansion)
	const MARGIN := 1
	var x0 := clampi(floori(min_xf - ex) - MARGIN, 0, w - 1)
	var x1 := clampi(ceili(max_xf + ex) - 1 + MARGIN, 0, w - 1)
	var y0 := clampi(floori(min_yf - ex) - MARGIN, 0, h - 1)
	var y1 := clampi(ceili(max_yf + ex) - 1 + MARGIN, 0, h - 1)
	if x0 > x1 or y0 > y1:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


## Bounds that cover thick segment quads plus round caps/joints — path vertices alone underestimate.
func _get_stroke_blend_bounds(stroke_points: PackedVector2Array, stroke_width: float, w: int, h: int) -> Rect2i:
	var min_xf := INF
	var max_xf := -INF
	var min_yf := INF
	var max_yf := -INF

	var hw := stroke_width / 2.0
	for i: int in range(stroke_points.size() - 1):
		var p1: Vector2 = stroke_points[i]
		var p2: Vector2 = stroke_points[i + 1]
		if p1.distance_to(p2) <= 0.001:
			continue
		var quad := _get_thick_line_rect(p1, p2, stroke_width)
		for j in range(quad.size()):
			var pv: Vector2 = quad[j]
			min_xf = minf(min_xf, pv.x)
			max_xf = maxf(max_xf, pv.x)
			min_yf = minf(min_yf, pv.y)
			max_yf = maxf(max_yf, pv.y)
	for pt: Vector2 in stroke_points:
		var cap := _circle_points_16gon(pt, hw)
		for j in range(cap.size()):
			var pv2: Vector2 = cap[j]
			min_xf = minf(min_xf, pv2.x)
			max_xf = maxf(max_xf, pv2.x)
			min_yf = minf(min_yf, pv2.y)
			max_yf = maxf(max_yf, pv2.y)

	if min_xf == INF:
		return Rect2i(0, 0, 0, 0)

	const MARGIN := 1
	var x0 := clampi(floori(min_xf) - MARGIN, 0, w - 1)
	var x1 := clampi(ceili(max_xf) - 1 + MARGIN, 0, w - 1)
	var y0 := clampi(floori(min_yf) - MARGIN, 0, h - 1)
	var y1 := clampi(ceili(max_yf) - 1 + MARGIN, 0, h - 1)
	if x0 > x1 or y0 > y1:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
