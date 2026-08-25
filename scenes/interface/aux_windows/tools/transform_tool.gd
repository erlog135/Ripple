extends RefCounted

## Hit-zone sizes in screen pixels (scaled by zoom into world units).
const HANDLE_SIZE := 8.0
const ROTATE_ZONE := 18.0

## Handle layout order: 0=TL 1=TR 2=BR 3=BL 4=TM 5=BM 6=LM 7=RM.
const _ANCHOR_OF := [2, 3, 0, 1, 5, 4, 7, 6]

var current_hover_mode: EditorState.TransformMode = EditorState.TransformMode.NONE
var hovered_handle: int = -1
## Desired mouse cursor shape for the current hover/drag state (a Control.CursorShape /
## Input.CursorShape value). The input layer reads this and applies it to its own
## `mouse_default_cursor_shape`, since the Control under the mouse owns the cursor.
var cursor_shape: int = Input.CURSOR_ARROW

var _dragging := false
var _locked_mode: EditorState.TransformMode = EditorState.TransformMode.NONE
var _drag_start_world := Vector2.ZERO
var _original_bounds := Rect2()

var _active_handle: int = -1
var _handle_origin := Vector2.ZERO
var _scale_anchor := Vector2.ZERO
var _scale_axes := Vector2.ZERO
var _rotate_pivot := Vector2.ZERO

# Each entry: { cmd_idx, points (PackedVector2Array), sel_pts, draw_type,
#               stroke_width, is_circle, circle_radius }
var _snapshot: Array = []


func handle_mouse_motion(world_pos: Vector2) -> void:
	if _dragging:
		EditorState.update_transform_matrix(_compute_matrix(world_pos))
	else:
		update_hover(world_pos)


func handle_left_press(world_pos: Vector2) -> void:
	if EditorState.selected_point_indices.is_empty():
		return
	update_hover(world_pos)
	if current_hover_mode == EditorState.TransformMode.NONE:
		return

	_dragging = true
	_locked_mode = current_hover_mode
	_drag_start_world = world_pos
	_original_bounds = EditorState.get_selection_bounds()

	if _locked_mode == EditorState.TransformMode.SCALE and _active_handle != -1:
		var positions := _handle_positions(_original_bounds)
		_handle_origin = positions[_active_handle]
		_scale_anchor = positions[_ANCHOR_OF[_active_handle]]
		_scale_axes = _handle_axes(_active_handle)
	elif _locked_mode == EditorState.TransformMode.ROTATE:
		_rotate_pivot = _original_bounds.get_center()

	_cache_snapshot()
	EditorState.begin_transform(_locked_mode)


func handle_left_release(world_pos: Vector2) -> void:
	if not _dragging:
		return

	var matrix := _compute_matrix(world_pos)
	if matrix != Transform2D.IDENTITY:
		_commit(matrix)

	_dragging = false
	_snapshot.clear()
	EditorState.end_transform()
	update_hover(world_pos)


func cancel() -> void:
	_dragging = false
	_snapshot.clear()
	current_hover_mode = EditorState.TransformMode.NONE
	hovered_handle = -1
	cursor_shape = Input.CURSOR_ARROW
	if EditorState.is_transform_previewing():
		EditorState.end_transform()


func update_hover(world_pos: Vector2) -> void:
	if EditorState.selected_point_indices.is_empty():
		_set_hover(EditorState.TransformMode.NONE, -1)
		return

	var bounds := EditorState.get_selection_bounds()
	var g := EditorState.get_gizmo_scale()
	var handle := HANDLE_SIZE * g
	var rot_zone := ROTATE_ZONE * g
	var has_x := bounds.size.x > 0.0001
	var has_y := bounds.size.y > 0.0001

	if not has_x and not has_y:
		# Single point (or degenerate selection): movement only.
		if bounds.grow(handle).has_point(world_pos):
			_set_hover(EditorState.TransformMode.MOVE, -1)
		else:
			_set_hover(EditorState.TransformMode.NONE, -1)
		return

	var hit := _hit_handle(world_pos, bounds, handle)
	if hit != -1:
		_active_handle = hit
		_set_hover(EditorState.TransformMode.SCALE, hit)
		return

	if has_x and has_y:
		if bounds.grow(rot_zone).has_point(world_pos) and not bounds.grow(handle).has_point(world_pos):
			_set_hover(EditorState.TransformMode.ROTATE, -1)
			return

	if bounds.grow(handle).has_point(world_pos):
		_set_hover(EditorState.TransformMode.MOVE, -1)
		return

	_set_hover(EditorState.TransformMode.NONE, -1)


func _set_hover(mode: EditorState.TransformMode, handle: int) -> void:
	current_hover_mode = mode
	hovered_handle = handle
	cursor_shape = _cursor_for(mode, handle)


func _cursor_for(mode: EditorState.TransformMode, handle: int) -> int:
	match mode:
		EditorState.TransformMode.MOVE:
			return Input.CURSOR_MOVE
		EditorState.TransformMode.ROTATE:
			return Input.CURSOR_CROSS
		EditorState.TransformMode.SCALE:
			match handle:
				0, 2:
					return Input.CURSOR_FDIAGSIZE
				1, 3:
					return Input.CURSOR_BDIAGSIZE
				4, 5:
					return Input.CURSOR_VSIZE
				6, 7:
					return Input.CURSOR_HSIZE
	return Input.CURSOR_ARROW


func _compute_matrix(world_pos: Vector2) -> Transform2D:
	var shift := Input.is_key_pressed(KEY_SHIFT)
	match _locked_mode:
		EditorState.TransformMode.MOVE:
			var delta := world_pos - _drag_start_world
			if shift:
				if absf(delta.x) > absf(delta.y):
					delta.y = 0.0
				else:
					delta.x = 0.0
			return Transform2D(0.0, delta)

		EditorState.TransformMode.SCALE:
			var alt := Input.is_key_pressed(KEY_ALT)
			var pivot := _original_bounds.get_center() if alt else _scale_anchor
			var delta := world_pos - _drag_start_world
			var v0 := _handle_origin - pivot
			var v1 := (_handle_origin + delta) - pivot
			var sf := Vector2.ONE
			if _scale_axes.x > 0.0 and absf(v0.x) > 0.0001:
				sf.x = v1.x / v0.x
			if _scale_axes.y > 0.0 and absf(v0.y) > 0.0001:
				sf.y = v1.y / v0.y
			if shift:
				if _scale_axes.x > 0.0 and _scale_axes.y > 0.0:
					var u := maxf(absf(sf.x), absf(sf.y))
					sf.x = (1.0 if sf.x >= 0.0 else -1.0) * u
					sf.y = (1.0 if sf.y >= 0.0 else -1.0) * u
				elif _scale_axes.x > 0.0:
					if _original_bounds.size.y > 0.0001:
						sf.y = sf.x
				else:
					if _original_bounds.size.x > 0.0001:
						sf.x = sf.y
			return _scale_matrix(pivot, sf)

		EditorState.TransformMode.ROTATE:
			var pivot := _rotate_pivot
			var a0 := (_drag_start_world - pivot).angle()
			var a1 := (world_pos - pivot).angle()
			var ang := a1 - a0
			if shift:
				ang = snappedf(ang, deg_to_rad(15.0))
			return _rotate_matrix(pivot, ang)

	return Transform2D.IDENTITY


func _scale_matrix(pivot: Vector2, sf: Vector2) -> Transform2D:
	var t := Transform2D.IDENTITY
	t.x = Vector2(sf.x, 0.0)
	t.y = Vector2(0.0, sf.y)
	t.origin = pivot - Vector2(sf.x * pivot.x, sf.y * pivot.y)
	return t


func _rotate_matrix(pivot: Vector2, ang: float) -> Transform2D:
	var t := Transform2D(ang, Vector2.ZERO)
	t.origin = pivot - t.basis_xform(pivot)
	return t


func _handle_positions(bounds: Rect2) -> Array:
	var p := bounds.position
	var s := bounds.size
	var c := bounds.get_center()
	return [
		p,                            # 0 TL
		Vector2(p.x + s.x, p.y),      # 1 TR
		p + s,                        # 2 BR
		Vector2(p.x, p.y + s.y),      # 3 BL
		Vector2(c.x, p.y),            # 4 TM
		Vector2(c.x, p.y + s.y),      # 5 BM
		Vector2(p.x, c.y),            # 6 LM
		Vector2(p.x + s.x, c.y),      # 7 RM
	]


func _handle_axes(idx: int) -> Vector2:
	match idx:
		4, 5:
			return Vector2(0.0, 1.0)
		6, 7:
			return Vector2(1.0, 0.0)
	return Vector2(1.0, 1.0)


func _hit_handle(world_pos: Vector2, bounds: Rect2, handle: float) -> int:
	var has_x := bounds.size.x > 0.0001
	var has_y := bounds.size.y > 0.0001
	var active_indices: Array[int] = []
	if has_x and has_y:
		active_indices = [0, 1, 2, 3, 4, 5, 6, 7]
	elif has_x:
		active_indices = [6, 7]
	elif has_y:
		active_indices = [4, 5]
	else:
		return -1

	var positions := _handle_positions(bounds)
	for i in active_indices:
		var hp: Vector2 = positions[i]
		var rect := Rect2(hp - Vector2(handle, handle), Vector2(handle, handle) * 2.0)
		if rect.has_point(world_pos):
			return i
	return -1


func _cache_snapshot() -> void:
	_snapshot.clear()
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return
	for cmd_idx in EditorState.selected_command_indices:
		if cmd_idx < 0 or cmd_idx >= frame.commands.size():
			continue
		var sel_pts: Array = EditorState.selected_point_indices.get(cmd_idx, [])
		if sel_pts.is_empty():
			continue
		var cmd: DrawCommand = frame.commands[cmd_idx]
		_snapshot.append({
			"cmd_idx": cmd_idx,
			"points": cmd.points.duplicate(),
			"sel_pts": sel_pts.duplicate(),
			"draw_type": cmd.draw_type,
			"stroke_width": cmd.stroke_width,
			"is_circle": cmd.draw_type == DrawCommand.Type.CIRCLE,
			"circle_radius": cmd.circle_radius,
			"path_open": cmd.path_open,
		})


func _commit(matrix: Transform2D) -> void:
	var frame: DrawCommandImage = ProjectData.get_current_image()
	if frame == null:
		return
	var frame_idx := EditorState.current_frame
	var is_move := _locked_mode == EditorState.TransformMode.MOVE
	# Circles keep one point but scale their radius by the matrix' average basis length.
	var radius_scale := (matrix.x.length() + matrix.y.length()) / 2.0

	var command_indices: Array[int] = []
	var new_points_arrays: Array = []
	var new_radii: Array = []
	var remapped_sel_pts: Dictionary = {}
	var path_close_indices: Array[int] = []

	for entry in _snapshot:
		var cmd_idx: int = entry["cmd_idx"]
		if cmd_idx >= frame.commands.size():
			continue
		var orig_points: PackedVector2Array = entry["points"]
		var sel_pts: Array = entry["sel_pts"]
		var draw_type: int = entry["draw_type"]
		var stroke_width: int = entry["stroke_width"]

		var transformed := orig_points.duplicate()
		for pt_idx in sel_pts:
			if pt_idx >= 0 and pt_idx < transformed.size():
				transformed[pt_idx] = EditorState.snap_world_position(
					matrix * orig_points[pt_idx], draw_type, stroke_width
				)

		var radius_new := -1
		if entry["is_circle"]:
			radius_new = maxi(1, roundi(float(entry["circle_radius"]) * radius_scale))

		if is_move:
			# Detect when the two endpoints of an open path land on the same position
			# after a move — the shape should be closed as part of the same action.
			if entry["path_open"] and not entry["is_circle"] and transformed.size() >= 2:
				if transformed[0] == transformed[transformed.size() - 1]:
					path_close_indices.append(cmd_idx)

			var merged := _merge_coincident(transformed, sel_pts)
			command_indices.append(cmd_idx)
			new_points_arrays.append(merged["points"])
			new_radii.append(radius_new)
			if not merged["new_sel"].is_empty() and merged["points"].size() < transformed.size():
				remapped_sel_pts[cmd_idx] = merged["new_sel"]
		else:
			command_indices.append(cmd_idx)
			new_points_arrays.append(transformed)
			new_radii.append(radius_new)

	if command_indices.is_empty():
		return

	HistoryManager.commit(TransformSelectionAction.new(
		frame_idx, command_indices, new_points_arrays, new_radii, path_close_indices
	))

	if not remapped_sel_pts.is_empty():
		for cmd_idx in remapped_sel_pts:
			EditorState.selected_point_indices[cmd_idx] = remapped_sel_pts[cmd_idx]
		EditorState.selection_changed.emit(false)


## Merges points that landed on the same position after a move and returns the
## deduped array plus the remapped selected-point indices (empty when nothing merged).
func _merge_coincident(points: PackedVector2Array, sel_pts: Array) -> Dictionary:
	var deduped := PackedVector2Array()
	var pos_to_idx: Dictionary = {}
	var old_to_new: Array = []
	for i in range(points.size()):
		var pos: Vector2 = points[i]
		if pos_to_idx.has(pos):
			old_to_new.append(-1)
		else:
			var new_idx: int = deduped.size()
			pos_to_idx[pos] = new_idx
			deduped.append(pos)
			old_to_new.append(new_idx)

	var new_sel: Array = []
	if deduped.size() < points.size():
		for old_idx in sel_pts:
			if old_idx >= 0 and old_idx < old_to_new.size():
				var mapped: int = old_to_new[old_idx]
				if mapped < 0:
					mapped = pos_to_idx[points[old_idx]]
				if mapped not in new_sel:
					new_sel.append(mapped)

	return { "points": deduped, "new_sel": new_sel }
