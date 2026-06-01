extends MenuBar

## Builds a native MenuBar from MenuSchema, dispatching actions through MenuDispatcher.


func _ready() -> void:
	prefer_global_menu = true
	_build_menus()
	MenuDispatcher.menu_state_changed.connect(_on_menu_state_changed)


func _build_menus() -> void:
	for category: String in MenuSchema.menu_data.keys():
		var popup := PopupMenu.new()
		popup.title = category
		popup.hide_on_state_item_selection = true
		add_child(popup)
		_populate_popup(popup, MenuSchema.menu_data[category])
		popup.index_pressed.connect(_on_index_pressed.bind(popup))
		popup.about_to_popup.connect(_refresh_popup_states.bind(popup))


func _populate_popup(popup: PopupMenu, items: Array) -> void:
	for item_data: Dictionary in items:
		var item_type: String = item_data.get("type", "action")
		var label: String = item_data.get("label", "")
		var action_id: String = item_data.get("id", "")
		var sc: Shortcut = item_data.get("shortcut", null)

		match item_type:
			"separator":
				popup.add_separator()
				popup.set_item_metadata(popup.item_count - 1, "")
			"checkbox":
				if sc:
					popup.add_check_shortcut(sc, -1, true)
				else:
					popup.add_check_item(label)
				var idx := popup.item_count - 1
				popup.set_item_text(idx, label)
				popup.set_item_metadata(idx, action_id)
			"radio":
				if sc:
					popup.add_radio_check_shortcut(sc, -1, true)
				else:
					popup.add_radio_check_item(label)
				var idx := popup.item_count - 1
				popup.set_item_text(idx, label)
				popup.set_item_metadata(idx, action_id)
			_:
				if sc:
					popup.add_shortcut(sc, -1, true)
				else:
					popup.add_item(label)
				var idx := popup.item_count - 1
				popup.set_item_text(idx, label)
				popup.set_item_metadata(idx, action_id)


func _on_index_pressed(index: int, popup: PopupMenu) -> void:
	var action_id: String = popup.get_item_metadata(index)
	if not action_id.is_empty():
		MenuDispatcher.execute(action_id)


func _on_menu_state_changed() -> void:
	for i in get_menu_count():
		_refresh_popup_states(get_menu_popup(i))


func _refresh_popup_states(popup: PopupMenu) -> void:
	for idx in popup.item_count:
		if popup.is_item_separator(idx):
			continue
		var action_id: String = popup.get_item_metadata(idx)
		if action_id.is_empty():
			continue
		var item_data := MenuSchema.get_item_by_id(action_id)
		var item_type: String = item_data.get("type", "")
		if item_type in ["checkbox", "radio"]:
			popup.set_item_checked(idx, MenuDispatcher.get_state(action_id))
