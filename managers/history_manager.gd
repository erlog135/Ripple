extends Node

const _EditAction = preload("res://data/actions/edit_action.gd")

## One UndoRedo instance per open tab. Indexed to match ProjectData.open_sequences.
var _undo_redos: Array[UndoRedo] = []


func _ready() -> void:
	ProjectData.tab_list_changed.connect(_on_tab_list_changed)
	ProjectData.tab_removed.connect(_on_tab_removed)


# ---------------------------------------------------------------------------
# Tab sync — called whenever the tab list structure changes
# ---------------------------------------------------------------------------

func _on_tab_list_changed() -> void:
	# Grow the array to match the new number of open tabs. Tabs are never
	# silently removed here; shrinking happens only via _on_tab_removed.
	while _undo_redos.size() < ProjectData.open_sequences.size():
		_undo_redos.append(UndoRedo.new())


func _on_tab_removed(index: int) -> void:
	if index < 0 or index >= _undo_redos.size():
		return
	_undo_redos[index].free()
	_undo_redos.remove_at(index)


# ---------------------------------------------------------------------------
# Internal helper
# ---------------------------------------------------------------------------

func _get_active() -> UndoRedo:
	var idx := ProjectData.active_sequence_index
	# Safety net: grow if signals haven't fired yet (e.g. during initialisation).
	while _undo_redos.size() <= idx:
		_undo_redos.append(UndoRedo.new())
	return _undo_redos[idx]


# ---------------------------------------------------------------------------
# Public API (same surface as before — all callers require zero changes)
# ---------------------------------------------------------------------------

func commit(action: _EditAction, merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE) -> void:
	var ur := _get_active()
	ur.create_action(action.action_name, merge_mode)
	ur.add_do_method(Callable(action, &"do_action"))
	ur.add_undo_method(Callable(action, &"undo_action"))
	ur.add_do_reference(action)
	ur.add_undo_reference(action)
	ur.commit_action()


## Clears the undo/redo history of the currently active tab only.
func clear() -> void:
	_get_active().clear_history()


## Clears all per-tab history stacks and frees every UndoRedo instance.
## Used by destructive operations such as File → New that replace all tabs.
func clear_all() -> void:
	for ur: UndoRedo in _undo_redos:
		ur.free()
	_undo_redos.clear()


func undo() -> void:
	var ur := _get_active()
	if ur.has_undo():
		ur.undo()


func redo() -> void:
	var ur := _get_active()
	if ur.has_redo():
		ur.redo()


## Removes the UndoRedo for the given tab index. Called by DocumentTabs when the
## user closes a tab, before ProjectData.close_sequence() shifts the array.
## NOTE: ProjectData already emits tab_removed which triggers _on_tab_removed;
## this public method exists for callers that need to coordinate ordering manually.
func remove_tab(index: int) -> void:
	_on_tab_removed(index)
