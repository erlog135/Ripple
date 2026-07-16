extends Node

const _EditAction = preload("res://data/actions/edit_action.gd")


# ---------------------------------------------------------------------------
# Public API (same surface as before — all callers require zero changes)
# ---------------------------------------------------------------------------

func commit(action: _EditAction, merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE) -> void:
	var doc = ProjectData.get_current_document()
	if not doc:
		return
	var ur: UndoRedo = doc.undo_redo
	ur.create_action(action.action_name, merge_mode)
	ur.add_do_method(Callable(action, &"do_action"))
	ur.add_undo_method(Callable(action, &"undo_action"))
	ur.add_do_reference(action)
	ur.add_undo_reference(action)
	ur.commit_action()
	
	_check_dirty_state(doc)


## Clears the undo/redo history of the currently active tab only.
func clear() -> void:
	var doc = ProjectData.get_current_document()
	if doc:
		doc.undo_redo.clear_history()
		_check_dirty_state(doc)


## Clears all per-tab history stacks and frees every UndoRedo instance.
## Used by destructive operations such as File → New that replace all tabs.
func clear_all() -> void:
	for doc in ProjectData.open_documents:
		doc.undo_redo.clear_history()
		_check_dirty_state(doc)


func undo() -> void:
	var doc = ProjectData.get_current_document()
	if doc and doc.undo_redo.has_undo():
		doc.undo_redo.undo()
		_check_dirty_state(doc)


func redo() -> void:
	var doc = ProjectData.get_current_document()
	if doc and doc.undo_redo.has_redo():
		doc.undo_redo.redo()
		_check_dirty_state(doc)


## Keeps compatibility with other code closing tabs.
func remove_tab(_index: int) -> void:
	pass


func mark_as_saved(doc: ProjectDocument, path: String) -> void:
	if not doc:
		return
	doc.file_path = path
	doc.saved_history_version = doc.undo_redo.get_version()
	_check_dirty_state(doc)


func _check_dirty_state(doc: ProjectDocument) -> void:
	if not doc:
		return
	var currently_dirty = (doc.undo_redo.get_version() != doc.saved_history_version)
	if doc.is_dirty != currently_dirty:
		doc.is_dirty = currently_dirty
		ProjectData.dirty_state_changed.emit()
