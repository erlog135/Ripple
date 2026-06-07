extends Node

signal menu_state_changed


func _ready() -> void:
	EditorState.render_mode_changed.connect(func(_mode): menu_state_changed.emit())
	EditorState.options_changed.connect(func(): menu_state_changed.emit())
	EditorState.clip_to_bounds_changed.connect(func(_enabled): menu_state_changed.emit())
	EditorState.validate_line_angles_changed.connect(func(_enabled): menu_state_changed.emit())


func execute(action_id: String) -> void:
	match action_id:
		"file_new":
			PopupManager.open("new_file", "res://scenes/interface/popups/NewFilePopup.tscn")
		"file_open":
			Fileman.open_file_dialog()
		"file_save":
			Fileman.save_file()
		"file_save_as":
			Fileman.save_as_file_dialog()
		"file_export_frame_pdc":
			Fileman.save_frame_as_pdc()
		"file_export_frame_png":
			Fileman.export_frame_as_png()
		"file_export_frame_png_flat":
			Fileman.export_frame_as_png(false)
		"file_export_sequence_gif":
			Fileman.export_sequence_as_gif()
		"edit_undo":
			HistoryManager.undo()
		"edit_redo":
			HistoryManager.redo()
		"edit_select_all":
			EditorState.select_all()
		"edit_deselect":
			EditorState.deselect_all()
		"view_raster":
			var next_mode := EditorState.RenderMode.VECTOR if EditorState.render_mode == EditorState.RenderMode.RASTER else EditorState.RenderMode.RASTER
			EditorState.set_render_mode(next_mode)
		"view_grid_snap":
			EditorState.grid_snap = not EditorState.grid_snap
			menu_state_changed.emit()
		"view_clip_to_bounds":
			EditorState.clip_to_document_bounds = not EditorState.clip_to_document_bounds
		"view_validate_angles":
			EditorState.validate_line_angles = not EditorState.validate_line_angles
		"view_zoom_in":
			EditorState.zoom_in_centered()
		"view_zoom_out":
			EditorState.zoom_out_centered()
		"view_zoom_actual":
			EditorState.zoom_actual_size()
		"view_zoom_document":
			EditorState.zoom_to_document(EditorState.canvas_viewport_size)
		"view_zoom_selection":
			EditorState.zoom_to_selection(EditorState.canvas_viewport_size)
		_:
			push_warning("MenuDispatcher: unknown action '%s'" % action_id)


func get_state(action_id: String) -> bool:
	match action_id:
		"view_raster":
			return EditorState.render_mode == EditorState.RenderMode.RASTER
		"view_grid_snap":
			return EditorState.grid_snap
		"view_clip_to_bounds":
			return EditorState.clip_to_document_bounds
		"view_validate_angles":
			return EditorState.validate_line_angles
	return false
