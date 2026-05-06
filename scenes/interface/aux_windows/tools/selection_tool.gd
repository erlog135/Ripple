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
	if not additive:
		EditorState.deselect_all()
	if single_hit_only:
		var best_hit: Array = gizmos.get_best_point_in_rect(rect, world_pos)
		if not best_hit.is_empty():
			EditorState.select_point(best_hit[0], best_hit[1], true)
		return

	var hits: Array = gizmos.get_points_in_rect(rect)
	for hit in hits:
		EditorState.select_point(hit[0], hit[1], true)
