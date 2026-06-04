extends Node

## Pure data blueprint for the top menu bar. UI code reads this and builds controls at runtime.

var menu_data: Dictionary = {}


func _ready() -> void:
	menu_data = _build_menu_data()


static func shortcut(key: Key, ctrl: bool = false, shift: bool = false, alt: bool = false) -> Shortcut:
	var event := InputEventKey.new()
	event.keycode = key
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	event.alt_pressed = alt
	var sc := Shortcut.new()
	sc.events.append(event)
	return sc


func get_item_by_id(action_id: String) -> Dictionary:
	for category_items: Array in menu_data.values():
		var found := _find_item_in_list(category_items, action_id)
		if not found.is_empty():
			return found
	return {}


func get_shortcut_for_action(action_id: String) -> Shortcut:
	var item := get_item_by_id(action_id)
	return item.get("shortcut") as Shortcut


func _find_item_in_list(items: Array, action_id: String) -> Dictionary:
	for item: Dictionary in items:
		if item.get("id", "") == action_id:
			return item
		if item.get("type", "") == "submenu" and item.has("children"):
			var found := _find_item_in_list(item["children"], action_id)
			if not found.is_empty():
				return found
	return {}


func _build_menu_data() -> Dictionary:
	return {
		"File": [
			{
				"id": "file_new",
				"type": "action",
				"label": "New...",
				"shortcut": shortcut(KEY_N, true),
			},
			{
				"id": "file_open",
				"type": "action",
				"label": "Open...",
				"shortcut": shortcut(KEY_O, true),
			},
			{
				"id": "file_save",
				"type": "action",
				"label": "Save",
				"shortcut": shortcut(KEY_S, true),
			},
			{
				"id": "file_save_as",
				"type": "action",
				"label": "Save As...",
				"shortcut": shortcut(KEY_S, true, true),
			},
			{"type": "separator"},
			{
				"type": "submenu",
				"label": "Export Current Frame",
				"children": [
					{
						"id": "file_export_frame_pdc",
						"type": "action",
						"label": "PDC...",
					},
					{
						"id": "file_export_frame_png",
						"type": "action",
						"label": "PNG (transparent)...",
					},
					{
						"id": "file_export_frame_png_flat",
						"type": "action",
						"label": "PNG (background)...",
					},
				],
			},
			{
				"id": "file_export_sequence_gif",
				"type": "action",
				"label": "Export Sequence as GIF...",
			},
		],
		"Edit": [
			{
				"id": "edit_undo",
				"type": "action",
				"label": "Undo",
				"shortcut": shortcut(KEY_Z, true),
			},
			{
				"id": "edit_redo",
				"type": "action",
				"label": "Redo",
				"shortcut": shortcut(KEY_Z, true, true),
			},
			{"type": "separator"},
			{
				"id": "edit_select_all",
				"type": "action",
				"label": "Select All",
				"shortcut": shortcut(KEY_A, true),
			},
			{
				"id": "edit_deselect",
				"type": "action",
				"label": "Deselect",
			},
		],
		"View": [
			{
				"id": "view_raster",
				"type": "checkbox",
				"label": "Raster Preview",
			},
			{"type": "separator"},
			{
				"id": "view_grid_snap",
				"type": "checkbox",
				"label": "Snap to Grid",
			},
			{
				"id": "view_clip_to_bounds",
				"type": "checkbox",
				"label": "Clip to Document Bounds",
			},
			{"type": "separator"},
			{
				"id": "view_zoom_in",
				"type": "action",
				"label": "Zoom In",
				"shortcut": shortcut(KEY_EQUAL, true),
			},
			{
				"id": "view_zoom_out",
				"type": "action",
				"label": "Zoom Out",
				"shortcut": shortcut(KEY_MINUS, true),
			},
			{"type": "separator"},
			{
				"id": "view_zoom_actual",
				"type": "action",
				"label": "Actual Size",
				"shortcut": shortcut(KEY_1, true),
			},
			{
				"id": "view_zoom_document",
				"type": "action",
				"label": "Zoom to Fit",
				"shortcut": shortcut(KEY_0, true),
			},
			{
				"id": "view_zoom_selection",
				"type": "action",
				"label": "Zoom to Selection",
				"shortcut": shortcut(KEY_0, true, true),
			},
		],
	}
