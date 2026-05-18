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
				"id": "file_open",
				"type": "action",
				"label": "Open...",
				"shortcut": shortcut(KEY_O, true),
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
				"id": "view_vector",
				"type": "radio",
				"label": "Vector Mode",
			},
			{
				"id": "view_raster",
				"type": "radio",
				"label": "Raster Preview",
			},
			{"type": "separator"},
			{
				"id": "view_grid_snap",
				"type": "checkbox",
				"label": "Snap to Grid",
			},
		],
	}
