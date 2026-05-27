extends Control

signal frame_selected(index: int)
signal resize_dragging(index: int, new_ms: int)
signal resize_committed(index: int, new_ms: int)
signal reorder_requested(from_index: int, insert_index_after_removal: int)

const MIN_WIDTH_PX := 64.0
const DRAG_KIND := "ripple_frame"
const DRAG_THRESHOLD_PX := 8.0

@onready var texture_rect: TextureRect = $Panel/TextureRect
@onready var drag_handle: VSeparator = $Panel/DragHandle
@onready var insertion_indicator: ColorRect = $Panel/InsertionIndicator
@onready var selector_rect: ReferenceRect = $Panel/SelectorRect
@onready var panel: Panel = $Panel

var frame_index: int = -1
var _zoom: float = 1.0
var _resize_dragging := false
var _resize_start_x := 0.0
var _resize_start_width := 0.0
var _committed_width_px := 0.0
var _reorder_drag_start_global: Vector2
var _reorder_drag_armed := false


func _ready() -> void:
	drag_handle.gui_input.connect(_on_drag_handle_gui_input)
	panel.gui_input.connect(_on_panel_gui_input)
	insertion_indicator.visible = false


func setup(idx: int, duration_ms: int, thumbnail: Texture2D, zoom: float, selected: bool) -> void:
	frame_index = idx
	_zoom = maxf(zoom, 0.0001)
	_committed_width_px = maxf(MIN_WIDTH_PX, float(duration_ms) * _zoom)
	custom_minimum_size.x = _committed_width_px
	size.x = _committed_width_px
	update_thumbnail(thumbnail)
	selector_rect.visible = selected


func update_thumbnail(thumbnail: Texture2D) -> void:
	if thumbnail != null:
		texture_rect.texture = thumbnail


func apply_zoom_only(zoom: float, duration_ms: int) -> void:
	_zoom = maxf(zoom, 0.0001)
	if _resize_dragging:
		return
	_committed_width_px = maxf(MIN_WIDTH_PX, float(duration_ms) * _zoom)
	custom_minimum_size.x = _committed_width_px
	size.x = _committed_width_px


func set_selected(selected: bool) -> void:
	selector_rect.visible = selected


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		insertion_indicator.visible = false


func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if drag_handle.get_global_rect().has_point(mb.global_position):
					return
				_reorder_drag_start_global = mb.global_position
				_reorder_drag_armed = true
				frame_selected.emit(frame_index)
			else:
				_reorder_drag_armed = false
	elif event is InputEventMouseMotion and _reorder_drag_armed:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if mm.global_position.distance_to(_reorder_drag_start_global) >= DRAG_THRESHOLD_PX:
				_reorder_drag_armed = false
				force_drag(_make_drag_payload(), _make_drag_preview())


func _on_drag_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_resize_dragging = true
				_reorder_drag_armed = false
				_resize_start_x = mb.global_position.x
				_resize_start_width = size.x
			else:
				if _resize_dragging:
					_resize_dragging = false
					_committed_width_px = custom_minimum_size.x
					var new_ms := int(round(custom_minimum_size.x / _zoom))
					new_ms = maxi(1, new_ms)
					resize_committed.emit(frame_index, new_ms)
	elif event is InputEventMouseMotion and _resize_dragging:
		var mm := event as InputEventMouseMotion
		var w := _resize_start_width + (mm.global_position.x - _resize_start_x)
		w = maxf(MIN_WIDTH_PX, w)
		custom_minimum_size.x = w
		size.x = w
		resize_dragging.emit(frame_index, maxi(1, int(round(w / _zoom))))


func _make_drag_payload() -> Dictionary:
	return {"kind": DRAG_KIND, "frame_index": frame_index}


func _make_drag_preview() -> Control:
	var preview := ColorRect.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.custom_minimum_size = Vector2(minf(size.x, 160.0), maxf(size.y, 32.0))
	preview.size = preview.custom_minimum_size
	preview.color = Color(0.25, 0.45, 0.85, 0.45)
	return preview


func _drag_kind_matches(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d := data as Dictionary
	return str(d.get("kind", "")) == DRAG_KIND and d.has("frame_index")


func _drag_source_index(data: Variant) -> int:
	return int((data as Dictionary)["frame_index"])


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not _drag_kind_matches(data):
		return false
	var from_idx := _drag_source_index(data)
	if from_idx == frame_index:
		insertion_indicator.visible = false
		return false
	var insert_before := frame_index
	if at_position.x >= size.x * 0.5:
		insert_before = frame_index + 1
	var insert_at := insert_before
	if from_idx < insert_at:
		insert_at -= 1
	if from_idx == insert_at:
		insertion_indicator.visible = false
		return false
	insertion_indicator.visible = true
	insertion_indicator.position.x = 0.0 if at_position.x < size.x * 0.5 else (size.x - insertion_indicator.size.x)
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	insertion_indicator.visible = false
	if not _drag_kind_matches(data):
		return
	var from_idx := _drag_source_index(data)
	var insert_before := frame_index
	if at_position.x >= size.x * 0.5:
		insert_before = frame_index + 1
	var insert_at := insert_before
	if from_idx < insert_at:
		insert_at -= 1
	if from_idx == insert_at:
		return
	reorder_requested.emit(from_idx, insert_at)
