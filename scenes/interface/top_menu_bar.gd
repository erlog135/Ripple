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
		popup.hide_on_item_selection = false
		popup.hide_on_checkable_item_selection = false
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
			"submenu":
				var sub := PopupMenu.new()
				sub.hide_on_item_selection = false
				sub.hide_on_checkable_item_selection = false
				sub.hide_on_state_item_selection = true
				popup.add_child(sub)
				popup.add_submenu_node_item(label, sub)
				popup.set_item_metadata(popup.item_count - 1, "")
				_populate_popup(sub, item_data.get("children", []))
				sub.index_pressed.connect(_on_index_pressed.bind(sub))
				sub.about_to_popup.connect(_refresh_popup_states.bind(sub))
			"dynamic_recent":
				var recent_sub := PopupMenu.new()
				recent_sub.hide_on_item_selection = false
				recent_sub.hide_on_checkable_item_selection = false
				recent_sub.hide_on_state_item_selection = true
				popup.add_child(recent_sub)
				popup.add_submenu_node_item(label, recent_sub)
				popup.set_item_metadata(popup.item_count - 1, "")
				_rebuild_recent_submenu(recent_sub)
				recent_sub.index_pressed.connect(_on_index_pressed.bind(recent_sub))
				recent_sub.about_to_popup.connect(_rebuild_recent_submenu.bind(recent_sub))
				SettingsManager.recent_files_changed.connect(_rebuild_recent_submenu.bind(recent_sub))
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


func _rebuild_recent_submenu(sub: PopupMenu) -> void:
	sub.clear()
	var recents: Array[String] = SettingsManager.recent_files
	if recents.is_empty():
		sub.add_item("No Recent Files")
		sub.set_item_disabled(0, true)
		sub.set_item_metadata(0, "")
	else:
		for path: String in recents:
			sub.add_item(path.get_file())
			var idx := sub.item_count - 1
			sub.set_item_metadata(idx, "file_open_recent::" + path)
			sub.set_item_tooltip(idx, path)
		sub.add_separator()
		sub.add_item("Clear Recent Files")
		sub.set_item_metadata(sub.item_count - 1, "file_clear_recent")


func _on_index_pressed(index: int, popup: PopupMenu) -> void:
	var meta: Variant = popup.get_item_metadata(index)
	if not (meta is String) or (meta as String).is_empty():
		return
	var action_id: String = meta as String
	var item_data := MenuSchema.get_item_by_id(action_id)
	var is_sticky: bool = item_data.get("sticky", false)
	MenuDispatcher.execute(action_id)
	if not is_sticky:
		popup.hide()


func _on_menu_state_changed() -> void:
	for i in get_menu_count():
		_refresh_popup_states(get_menu_popup(i))


func _refresh_popup_states(popup: PopupMenu) -> void:
	for idx in popup.item_count:
		if popup.is_item_separator(idx):
			continue
		var sub := popup.get_item_submenu_node(idx)
		if sub != null:
			_refresh_popup_states(sub)
			continue
		var meta: Variant = popup.get_item_metadata(idx)
		if not (meta is String) or (meta as String).is_empty():
			continue
		var action_id: String = meta as String
		var item_data := MenuSchema.get_item_by_id(action_id)
		var item_type: String = item_data.get("type", "")
		if item_type in ["checkbox", "radio"]:
			popup.set_item_checked(idx, MenuDispatcher.get_state(action_id))
