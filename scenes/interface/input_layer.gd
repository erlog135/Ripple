extends Control

@onready var _gizmos = $"../DocumentLayer/SubViewport/DocumentGizmos"

var _select_drag_start_world := Vector2.ZERO
var _select_drag_end_world := Vector2.ZERO
var _select_dragging := false
var _select_drag_additive := false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		EditorState.update_mouse_position(event.position)

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if EditorState.active_tool == EditorState.Tool.PAN:
			EditorState.pan(-event.relative)
		elif EditorState.active_tool == EditorState.Tool.SELECT and _select_dragging:
			_select_drag_end_world = _screen_to_world(event.position)
			_gizmos.set_drag_selection_rect(_normalized_rect(_select_drag_start_world, _select_drag_end_world), true)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		EditorState.zoom_in(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		EditorState.zoom_out(event.position)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if EditorState.active_tool == EditorState.Tool.SELECT:
			var world_pos := _screen_to_world(event.position)
			if event.pressed:
				_select_drag_start_world = world_pos
				_select_drag_end_world = world_pos
				_select_dragging = true
				_select_drag_additive = Input.is_key_pressed(KEY_SHIFT)
				_gizmos.set_drag_selection_rect(_selection_rect_from_drag(), true)
			elif _select_dragging:
				_select_drag_end_world = world_pos
				_apply_rect_selection(_selection_rect_from_drag(), _select_drag_additive)
				_select_dragging = false
				_gizmos.set_drag_selection_rect(Rect2(), false)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var canvas_center := get_rect().size / 2.0
	return EditorState.current_camera_pos + (screen_pos - canvas_center) / EditorState.current_zoom

func _selection_rect_from_drag() -> Rect2:
	var drag_rect := _normalized_rect(_select_drag_start_world, _select_drag_end_world)
	if drag_rect.size == Vector2.ZERO:
		var half_size := Vector2(0.5, 0.5)
		return Rect2(_select_drag_start_world - half_size, Vector2.ONE)
	return drag_rect

func _normalized_rect(a: Vector2, b: Vector2) -> Rect2:
	var top_left := a.min(b)
	var bottom_right := a.max(b)
	return Rect2(top_left, bottom_right - top_left)

func _apply_rect_selection(rect: Rect2, additive: bool) -> void:
	var hits: Array = _gizmos.get_points_in_rect(rect)
	if not additive:
		EditorState.deselect_all()
	for hit in hits:
		EditorState.select_point(hit[0], hit[1], true)
