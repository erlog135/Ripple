extends RefCounted

var _drag_start_world := Vector2.ZERO
var _drag_end_world := Vector2.ZERO
var _dragging := false
var _drag_has_moved := false
var _drag_additive := false


func handle_mouse_motion(world_pos: Vector2, gizmos) -> void:
	if not _dragging:
		return

	_drag_end_world = world_pos
	_drag_has_moved = _drag_has_moved or _drag_end_world != _drag_start_world
	if _drag_has_moved:
		gizmos.set_drag_selection_rect(_normalized_rect(_drag_start_world, _drag_end_world), true)

func handle_left_press(world_pos: Vector2, additive: bool) -> void:
	_drag_start_world = world_pos
	_drag_end_world = world_pos
	_dragging = true
	_drag_has_moved = false
	_drag_additive = additive

func handle_left_release(world_pos: Vector2, gizmos) -> void:
	if not _dragging:
		return

	_drag_end_world = world_pos
	var is_click := not _drag_has_moved
	_apply_rect_selection(_selection_rect_from_drag(), _drag_additive, is_click, world_pos, gizmos)
	_dragging = false
	gizmos.set_drag_selection_rect(Rect2(), false)

func cancel(gizmos) -> void:
	_dragging = false
	_drag_has_moved = false
	gizmos.set_drag_selection_rect(Rect2(), false)

func _selection_rect_from_drag() -> Rect2:
	var drag_rect := _normalized_rect(_drag_start_world, _drag_end_world)
	if drag_rect.size == Vector2.ZERO:
		var half_size := Vector2(0.5, 0.5)
		return Rect2(_drag_start_world - half_size, Vector2.ONE)
	return drag_rect

func _normalized_rect(a: Vector2, b: Vector2) -> Rect2:
	var top_left := a.min(b)
	var bottom_right := a.max(b)
	return Rect2(top_left, bottom_right - top_left)

func _apply_rect_selection(rect: Rect2, additive: bool, single_hit_only: bool, world_pos: Vector2, gizmos) -> void:
	if single_hit_only:
		var best_hit: Array = gizmos.get_best_point_in_rect(rect, world_pos)
		if best_hit.is_empty():
			if not additive and not _is_inside_selection_bounds(world_pos):
				EditorState.deselect_all()
			return
		var cmd_idx: int = best_hit[0]
		var pt_idx: int = best_hit[1]
		var sel: Dictionary = EditorState.selected_point_indices
		if not additive and sel.has(cmd_idx) and pt_idx in sel[cmd_idx]:
			return
		if not additive:
			EditorState.deselect_all()
		EditorState.select_point(cmd_idx, pt_idx, true)
		return

	if not additive:
		EditorState.deselect_all()
	var hits: Array = gizmos.get_points_in_rect(rect)
	for hit in hits:
		EditorState.select_point(hit[0], hit[1], true)


func _is_inside_selection_bounds(world_pos: Vector2) -> bool:
	if EditorState.selected_point_indices.is_empty():
		return false
	var g := EditorState.get_gizmo_scale()
	return EditorState.get_selection_bounds().grow(8.0 * g).has_point(world_pos)
