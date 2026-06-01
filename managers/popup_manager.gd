extends Node

## Registry for unique, blocking popups (the "New..." dialog, the color picker, etc.).
##
## Triggers (menu items, shortcuts, widgets) call [method open] with a stable id
## and a scene path. The manager guarantees a single live instance per id: spamming
## a shortcut just re-focuses the existing window instead of stacking duplicates.
## Popups are lazily loaded on first request and erased from the cache when they
## leave the tree (via [code]queue_free[/code]), so nothing lingers in memory.

var _active_popups: Dictionary = {}


## Opens the popup registered under [param popup_id], loading [param scene_path]
## on first use. If a popup with this id is already open it is brought to the
## front instead of being duplicated. Returns the live popup instance (or null
## when the scene fails to load) so callers can connect signals or configure it.
func open(popup_id: String, scene_path: String) -> Window:
	if _active_popups.has(popup_id):
		var existing: Window = _active_popups[popup_id]
		existing.grab_focus()
		return existing

	var scene: PackedScene = load(scene_path)
	if scene == null:
		push_error("PopupManager: failed to load popup scene '%s'" % scene_path)
		return null

	var popup: Window = scene.instantiate()
	get_tree().root.add_child(popup)
	_active_popups[popup_id] = popup
	popup.tree_exited.connect(func() -> void: _active_popups.erase(popup_id))
	popup.popup_centered()
	return popup


## Returns the live instance for [param popup_id], or null when it is not open.
func get_popup(popup_id: String) -> Window:
	return _active_popups.get(popup_id)


## Returns true when a popup with [param popup_id] is currently open.
func is_open(popup_id: String) -> bool:
	return _active_popups.has(popup_id)


## Closes the popup registered under [param popup_id] if it is open. Freeing the
## node triggers its [code]tree_exited[/code] signal, which clears the cache entry.
func close(popup_id: String) -> void:
	if _active_popups.has(popup_id):
		_active_popups[popup_id].queue_free()
