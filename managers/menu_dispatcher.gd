extends Node

signal menu_state_changed


func _ready() -> void:
	EditorState.render_mode_changed.connect(func(_mode): menu_state_changed.emit())
	EditorState.options_changed.connect(func(): menu_state_changed.emit())


func execute(action_id: String) -> void:
	match action_id:
		"file_open":
			Fileman.open_file_dialog()
		"edit_undo":
			HistoryManager.undo()
		"edit_redo":
			HistoryManager.redo()
		"edit_select_all":
			EditorState.select_all()
		"edit_deselect":
			EditorState.deselect_all()
		"view_vector":
			EditorState.set_render_mode(EditorState.RenderMode.VECTOR)
		"view_raster":
			EditorState.set_render_mode(EditorState.RenderMode.RASTER)
		"view_grid_snap":
			EditorState.grid_snap = not EditorState.grid_snap
			menu_state_changed.emit()
		_:
			push_warning("MenuDispatcher: unknown action '%s'" % action_id)


func get_state(action_id: String) -> bool:
	match action_id:
		"view_vector":
			return EditorState.render_mode == EditorState.RenderMode.VECTOR
		"view_raster":
			return EditorState.render_mode == EditorState.RenderMode.RASTER
		"view_grid_snap":
			return EditorState.grid_snap
	return false


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	for category_items: Array in MenuSchema.menu_data.values():
		for item: Dictionary in category_items:
			if _try_execute_shortcut_item(item, event):
				return


func _try_execute_shortcut_item(item: Dictionary, event: InputEvent) -> bool:
	if item.has("shortcut"):
		var sc: Shortcut = item["shortcut"]
		if sc.matches_event(event):
			if item.has("id"):
				execute(item["id"])
				get_viewport().set_input_as_handled()
				return true
	if item.get("type", "") == "submenu" and item.has("children"):
		for child: Dictionary in item["children"]:
			if _try_execute_shortcut_item(child, event):
				return true
	return false
