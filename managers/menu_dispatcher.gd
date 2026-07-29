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
		"file_import_svg":
			Fileman.import_svg_dialog()
		"file_import_svg_sequence":
			Fileman.import_svg_sequence_dialog()
		"file_save":
			Fileman.save_file()
		"file_save_as":
			Fileman.save_as_file_dialog()
		"file_export_frame_pdc":
			Fileman.save_frame_as_pdc()
		"file_export_frame_svg":
			Fileman.export_frame_as_svg_dialog()
		"file_export_frame_png":
			Fileman.export_frame_as_png()
		"file_export_sequence_gif":
			Fileman.export_sequence_as_gif()
		"file_export_sequence_animated_svg":
			Fileman.export_sequence_as_animated_svg_dialog()
		"file_export_sequence_multiple_svgs":
			Fileman.export_sequence_as_multiple_svgs_dialog()
		"file_export_all_tabs_pdc":
			Fileman.export_all_tabs_as_pdc()
		"edit_undo":
			HistoryManager.undo()
		"edit_redo":
			HistoryManager.redo()
		"edit_cut":
			ClipboardManager.cut_selection()
		"edit_copy":
			ClipboardManager.copy_selection()
		"edit_paste":
			ClipboardManager.paste()
		"edit_duplicate":
			ClipboardManager.duplicate_selection()
		"edit_select_all":
			EditorState.select_all()
		"edit_deselect":
			EditorState.deselect_all()
		"image_resize":
			PopupManager.open("resize_document", "res://scenes/interface/popups/ResizeDocumentPopup.tscn")
		"image_flip_horizontal":
			var action := TransformSelectionAction.create_image_flip(true)
			if action:
				HistoryManager.commit(action)
		"image_flip_vertical":
			var action := TransformSelectionAction.create_image_flip(false)
			if action:
				HistoryManager.commit(action)
		"image_rotate_90_cw":
			var action := TransformSelectionAction.create_image_rotate(true)
			if action:
				HistoryManager.commit(action)
		"image_rotate_90_ccw":
			var action := TransformSelectionAction.create_image_rotate(false)
			if action:
				HistoryManager.commit(action)
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
		"view_ui_scale_up":
			get_tree().root.content_scale_factor = clampf(
					get_tree().root.content_scale_factor + 0.1, 0.5, 3.0)
		"view_ui_scale_down":
			get_tree().root.content_scale_factor = clampf(
					get_tree().root.content_scale_factor - 0.1, 0.5, 3.0)
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
		"help_src":
			OS.shell_open("https://github.com/erlog135/Ripple")
		"help_pdc_docs":
			OS.shell_open("https://developer.rebble.io/guides/graphics-and-animations/vector-graphics/")
		"help_style_guide":
			OS.shell_open("https://github.com/pebble-dev/iconography/blob/master/STYLE-GUIDE.md")
		"help_art":
			OS.shell_open("https://discordapp.com/invite/aRUAYFN")
		"help_app":
			OS.shell_open("mailto:loganhead_net+rpl@proton.me?subject=Message%20about%20Ripple")
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
