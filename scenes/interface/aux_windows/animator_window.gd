extends Control

@onready var playback_speed_spin: SpinBox = $PlaybackPanel/PlaybackSpeed
@onready var loop_toggle: CheckBox = $PlaybackPanel/LoopToggle
@onready var last_frame_button: Button = $PlaybackPanel/LastFrameButton
@onready var play_button: Button = $PlaybackPanel/PlayButton
@onready var first_frame_button: Button = $PlaybackPanel/FirstFrameButton

@onready var delete_frame_button: Button = $PlaybackPanel/DeleteFrameButton
@onready var new_frame_button: Button = $PlaybackPanel/NewFrameButton
@onready var duplicate_frame_button: Button = $PlaybackPanel/DuplicateFrameButton
@onready var current_frame_spin: SpinBox = $PlaybackPanel/CurrentFrame
@onready var onion_skin_toggle: CheckButton = $PlaybackPanel/OnionSkinToggle
@onready var frame_duration: SpinBox = $PlaybackPanel/FrameDuration
@onready var move_frame_right_button: Button = $PlaybackPanel/MoveFrameRightButton
@onready var move_frame_left_button: Button = $PlaybackPanel/MoveFrameLeftButton


@onready var frames_panel: Panel = $FramesPanel
@onready var scroll_container: ScrollContainer = $FramesPanel/ScrollContainer
@onready var playhead: Node2D = $FramesPanel/Playhead
@onready var playhead_line: Line2D = $FramesPanel/Playhead/Line2D
@onready var playhead_grab_point: TextureRect = $FramesPanel/Playhead/GrabPoint

@onready var frames_container: HBoxContainer = $FramesPanel/ScrollContainer/Frames

const FRAME_ITEM_SCENE := preload("uid://lkjmvossobbc")

var _playing := false
var _playback_timer := 0.0
var _suppress_duration := false
var _suppress_current_frame_spin := false
var _dragging_playhead := false


func _ready() -> void:
	first_frame_button.toggle_mode = false
	last_frame_button.toggle_mode = false

	play_button.toggled.connect(_on_play_toggled)
	delete_frame_button.pressed.connect(_on_delete_frame_pressed)
	new_frame_button.pressed.connect(_on_new_frame_pressed)
	duplicate_frame_button.pressed.connect(_on_duplicate_frame_pressed)
	first_frame_button.pressed.connect(_on_first_frame_pressed)
	last_frame_button.pressed.connect(_on_last_frame_pressed)
	move_frame_left_button.pressed.connect(_on_move_frame_left_pressed)
	move_frame_right_button.pressed.connect(_on_move_frame_right_pressed)

	playback_speed_spin.value = EditorState.playback_speed
	playback_speed_spin.value_changed.connect(_on_playback_speed_spin_changed)

	frame_duration.max_value = 60000.0
	frame_duration.value_changed.connect(_on_frame_duration_changed)
	current_frame_spin.value_changed.connect(_on_current_frame_spin_changed)

	ProjectData.data_changed.connect(_on_project_data_changed)
	RenderManager.bulk_raster_finished.connect(_rebuild_timeline)
	EditorState.current_frame_changed.connect(_on_editor_current_frame_changed)
	EditorState.timeline_zoom_changed.connect(_on_timeline_zoom_changed)

	frames_panel.gui_input.connect(_on_frames_panel_gui_input)
	scroll_container.gui_input.connect(_on_frames_panel_gui_input)

	var hscroll := scroll_container.get_h_scroll_bar()
	if hscroll != null:
		hscroll.value_changed.connect(_on_scroll_horizontal_changed)

	scroll_container.resized.connect(_on_scroll_container_resized)
	scroll_container.item_rect_changed.connect(_on_scroll_container_resized)

	frames_container.sort_children.connect(_on_frames_container_sorted)

	playhead_grab_point.gui_input.connect(_on_playhead_grab_point_gui_input)
	playhead_grab_point.mouse_default_cursor_shape = Control.CURSOR_MOVE

	set_process(false)
	visibility_changed.connect(_on_visibility_changed)
	_rebuild_timeline()
	_sync_process_state()


func _on_visibility_changed() -> void:
	if not visible and _playing:
		_set_playing(false)
	_sync_process_state()


func _process(delta: float) -> void:
	if _dragging_playhead:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_dragging_playhead = false
			_sync_process_state()
		else:
			_scrub_playhead_from_global_mouse(get_global_mouse_position())
	if not _playing:
		return
	var seq := ProjectData.current_sequence
	if seq == null or seq.frames.is_empty():
		_set_playing(false)
		return
	var cf := EditorState.current_frame
	if cf < 0 or cf >= seq.frame_durations_ms.size():
		_set_playing(false)
		return
	_playback_timer += delta * EditorState.playback_speed
	var dur_sec := float(seq.frame_durations_ms[cf]) / 1000.0
	if dur_sec <= 0.0:
		dur_sec = 0.001
	if _playback_timer < dur_sec:
		return
	_playback_timer -= dur_sec
	var next := cf + 1
	if next >= seq.frames.size():
		if loop_toggle.button_pressed:
			next = 0
		else:
			next = seq.frames.size() - 1
			EditorState.set_current_frame(next)
			_set_playing(false)
			return
	EditorState.set_current_frame(next)


func _on_frames_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			EditorState.set_timeline_zoom(EditorState.timeline_zoom * 1.1)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			EditorState.set_timeline_zoom(EditorState.timeline_zoom / 1.1)
			accept_event()


func _on_project_data_changed(_by_user: bool, affected_frame: int) -> void:
	if RenderManager.is_rasterizing:
		# Bulk rasterization is running async; _rebuild_timeline fires on bulk_raster_finished.
		return
	if RenderManager.preview_layout_changed:
		_rebuild_timeline()
		return
	if affected_frame >= 0 and _refresh_frame_thumbnail(affected_frame):
		return
	_rebuild_timeline()


func _refresh_frame_thumbnail(frame_index: int) -> bool:
	if frame_index < 0 or frame_index >= frames_container.get_child_count():
		return false
	var item := frames_container.get_child(frame_index)
	if not item.has_method("update_thumbnail"):
		return false
	item.update_thumbnail(RenderManager.get_frame_texture(frame_index))
	return true


func _on_timeline_zoom_changed() -> void:
	_refresh_strip_zoom()


func _on_editor_current_frame_changed(_frame: int) -> void:
	_update_playhead_and_ui()


func _on_scroll_container_resized() -> void:
	_update_playhead_and_ui()


func _on_scroll_horizontal_changed(_value: float) -> void:
	_update_playhead_and_ui()


func _on_frames_container_sorted() -> void:
	_apply_playhead_visuals(_playhead_left_x())


func _on_play_toggled(pressed: bool) -> void:
	_set_playing(pressed)


func _set_playing(playing: bool) -> void:
	_playing = playing
	EditorState.is_playing = playing
	_sync_process_state()
	if _playing:
		_playback_timer = 0.0
		var seq := ProjectData.current_sequence
		if seq != null and not seq.frames.is_empty() and not loop_toggle.button_pressed:
			if EditorState.current_frame >= seq.frames.size() - 1:
				EditorState.set_current_frame(0)
	if play_button.button_pressed != playing:
		play_button.set_pressed_no_signal(playing)


func _on_delete_frame_pressed() -> void:
	var seq := ProjectData.current_sequence
	if seq == null or seq.frames.size() <= 1:
		return
	var cf := EditorState.current_frame
	if cf < 0 or cf >= seq.frames.size():
		return
	var target := maxi(0, cf - 1)
	HistoryManager.commit(DeleteFrameAction.new(cf))
	EditorState.set_current_frame(target)


func _on_new_frame_pressed() -> void:
	var seq := ProjectData.current_sequence
	if seq == null:
		return
	var insert_at := mini(EditorState.current_frame + 1, seq.frames.size())
	HistoryManager.commit(AddFrameAction.new(insert_at))
	EditorState.set_current_frame(insert_at)


func _on_duplicate_frame_pressed() -> void:
	var seq := ProjectData.current_sequence
	if seq == null or seq.frames.is_empty():
		return
	var src := EditorState.current_frame
	if src < 0 or src >= seq.frames.size():
		return
	HistoryManager.commit(DuplicateFrameAction.new(src))
	EditorState.set_current_frame(src + 1)


func _on_first_frame_pressed() -> void:
	EditorState.set_current_frame(0)


func _on_last_frame_pressed() -> void:
	var seq := ProjectData.current_sequence
	if seq == null or seq.frames.is_empty():
		return
	EditorState.set_current_frame(seq.frames.size() - 1)


func _on_move_frame_left_pressed() -> void:
	var seq := ProjectData.current_sequence
	if seq == null or seq.frames.size() < 2:
		return
	var cf := EditorState.current_frame
	if cf <= 0:
		return
	HistoryManager.commit(ReorderFrameAction.new(cf, cf - 1))


func _on_move_frame_right_pressed() -> void:
	var seq := ProjectData.current_sequence
	if seq == null or seq.frames.size() < 2:
		return
	var cf := EditorState.current_frame
	if cf >= seq.frames.size() - 1:
		return
	HistoryManager.commit(ReorderFrameAction.new(cf, cf + 1))


func _on_playback_speed_spin_changed(value: float) -> void:
	EditorState.playback_speed = value


func _on_current_frame_spin_changed(value: float) -> void:
	if _suppress_current_frame_spin:
		return
	EditorState.set_current_frame(int(value) - 1)


func _on_frame_duration_changed(value: float) -> void:
	if _suppress_duration:
		return
	var seq := ProjectData.current_sequence
	if seq == null:
		return
	var idx := EditorState.current_frame
	if idx < 0 or idx >= seq.frame_durations_ms.size():
		return
	var old_ms := int(seq.frame_durations_ms[idx])
	var new_ms := maxi(1, int(value))
	if new_ms == old_ms:
		return
	HistoryManager.commit(ChangeFrameDelayAction.new(idx, old_ms, new_ms))


func _sync_process_state() -> void:
	set_process(_playing or _dragging_playhead)


func _on_playhead_grab_point_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging_playhead = mb.pressed
			_sync_process_state()
			if mb.pressed:
				_scrub_playhead_from_global_mouse(mb.global_position)


func _scrub_playhead_from_global_mouse(global_pos: Vector2) -> void:
	var seq := ProjectData.current_sequence
	if seq == null or seq.frames.is_empty():
		return
	EditorState.set_current_frame(_frame_index_at_global_x(global_pos.x))


func _frame_index_at_global_x(global_x: float) -> int:
	var n := frames_container.get_child_count()
	if n == 0:
		return 0
	for i in range(n):
		var c := frames_container.get_child(i) as Control
		var r := c.get_global_rect()
		if global_x < r.position.x + r.size.x:
			return i
	return n - 1


func _global_x_to_frames_panel_local_x(global_x: float) -> float:
	var inv: Transform2D = frames_panel.get_global_transform().affine_inverse()
	var gy: float = frames_panel.get_global_rect().position.y
	return (inv * Vector2(global_x, gy)).x


func _playhead_left_x() -> float:
	var cf := EditorState.current_frame
	if cf < 0 or cf >= frames_container.get_child_count():
		return _global_x_to_frames_panel_local_x(scroll_container.get_global_rect().position.x)
	var item := frames_container.get_child(cf) as Control
	return _global_x_to_frames_panel_local_x(item.get_global_rect().position.x)


func _apply_playhead_visuals(playhead_x: float) -> void:
	playhead.position.x = playhead_x
	if playhead_line != null:
		var h: float = maxf(
			32.0,
			scroll_container.position.y + scroll_container.size.y
		)
		playhead_line.points = PackedVector2Array([Vector2.ZERO, Vector2(0, h)])


func _deferred_playhead_after_layout() -> void:
	if not is_inside_tree():
		return
	var x := _playhead_left_x()
	_apply_playhead_visuals(x)
	if not _dragging_playhead:
		return
	var cf := EditorState.current_frame
	if cf >= 0 and cf < frames_container.get_child_count():
		var c := frames_container.get_child(cf) as Control
		scroll_container.ensure_control_visible(c)


func _rebuild_timeline() -> void:
	for c in frames_container.get_children():
		frames_container.remove_child(c)
		c.queue_free()
	var seq := ProjectData.current_sequence
	if seq == null:
		_update_playhead_and_ui()
		return
	var n := seq.frames.size()
	for i in n:
		var item: Control = FRAME_ITEM_SCENE.instantiate()
		var dur := 35
		if i < seq.frame_durations_ms.size():
			dur = int(seq.frame_durations_ms[i])
		item.frame_selected.connect(_on_frame_item_selected)
		item.resize_dragging.connect(_on_frame_item_resize_dragging)
		item.resize_committed.connect(_on_frame_item_resize_committed)
		item.reorder_requested.connect(_on_frame_item_reorder_requested)
		frames_container.add_child(item)
		item.setup(i, dur, RenderManager.get_frame_texture(i), EditorState.timeline_zoom, i == EditorState.current_frame)
	_update_playhead_and_ui()


func _refresh_strip_zoom() -> void:
	var seq := ProjectData.current_sequence
	if seq == null:
		return
	var i := 0
	for child in frames_container.get_children():
		if child.has_method("apply_zoom_only") and i < seq.frame_durations_ms.size():
			child.apply_zoom_only(EditorState.timeline_zoom, int(seq.frame_durations_ms[i]))
		i += 1
	_update_playhead_and_ui()


func _on_frame_item_selected(index: int) -> void:
	EditorState.set_current_frame(index)


func _on_frame_item_resize_dragging(index: int, new_ms: int) -> void:
	if index != EditorState.current_frame:
		return
	_suppress_duration = true
	frame_duration.value = float(new_ms)
	_suppress_duration = false


func _on_frame_item_resize_committed(index: int, new_ms: int) -> void:
	var seq := ProjectData.current_sequence
	if seq == null or index < 0 or index >= seq.frame_durations_ms.size():
		return
	var old_ms := int(seq.frame_durations_ms[index])
	if old_ms == new_ms:
		return
	HistoryManager.commit(ChangeFrameDelayAction.new(index, old_ms, new_ms))


func _on_frame_item_reorder_requested(from_index: int, insert_index_after_removal: int) -> void:
	if from_index == insert_index_after_removal:
		return
	HistoryManager.commit(ReorderFrameAction.new(from_index, insert_index_after_removal))


func _update_playhead_and_ui() -> void:
	var seq := ProjectData.current_sequence
	var n := 0 if seq == null else seq.frames.size()
	var cf := EditorState.current_frame

	var playhead_x := _playhead_left_x()
	_apply_playhead_visuals(playhead_x)
	call_deferred("_deferred_playhead_after_layout")

	_suppress_current_frame_spin = true
	current_frame_spin.max_value = maxf(1.0, float(n))
	current_frame_spin.suffix = "/ %d" % maxi(1, n)
	current_frame_spin.value = float(cf + 1)
	_suppress_current_frame_spin = false

	if seq != null and n > 0 and cf >= 0 and cf < seq.frame_durations_ms.size():
		_suppress_duration = true
		frame_duration.value = float(seq.frame_durations_ms[cf])
		_suppress_duration = false
	else:
		_suppress_duration = true
		frame_duration.value = 35.0
		_suppress_duration = false

	delete_frame_button.disabled = n <= 1
	move_frame_left_button.disabled = n < 2 or cf <= 0
	move_frame_right_button.disabled = n < 2 or cf >= n - 1

	var idx := 0
	for child in frames_container.get_children():
		if child.has_method("set_selected"):
			child.set_selected(idx == cf)
		idx += 1
