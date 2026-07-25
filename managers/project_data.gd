extends Node

signal data_changed(by_user: bool, affected_frame: int)
## Emitted whenever the set of open tabs changes (add, close, replace).
signal tab_list_changed
## Emitted just before a tab is removed, so listeners (e.g. HistoryManager) can
## clean up per-tab state before the array shrinks. Index refers to the
## open_sequences position being removed.
signal tab_removed(index: int)
## Emitted when a tab's dirty state changes.
signal dirty_state_changed

var open_documents: Array[ProjectDocument] = []
var active_document_index: int = 0

# ---------------------------------------------------------------------------
# Backward-compatibility computed properties
# ---------------------------------------------------------------------------

var open_sequences: Array[DrawCommandSequence]:
	get:
		var arr: Array[DrawCommandSequence] = []
		for doc in open_documents:
			arr.append(doc.sequence)
		return arr

var sequence_paths: Array[String]:
	get:
		var arr: Array[String] = []
		for doc in open_documents:
			arr.append(doc.file_path)
		return arr

var active_sequence_index: int:
	get:
		return active_document_index
	set(value):
		active_document_index = value

## The currently active DrawCommandSequence. Read-only; use set_active_sequence
## or add_sequence to change which sequence is active.
var current_sequence: DrawCommandSequence:
	get: return get_current_sequence()

## The save path of the currently active tab.
## Writing to this updates the active tab's entry in sequence_paths.
var current_path: String:
	get:
		var doc = get_current_document()
		if not doc:
			return ""
		return doc.file_path
	set(value):
		var doc = get_current_document()
		if doc:
			doc.file_path = value


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_window_close_requested()


func _on_window_close_requested() -> void:
	var has_unsaved := false
	for doc in open_documents:
		if doc.is_dirty:
			has_unsaved = true
			break
	
	if has_unsaved:
		var popup = PopupManager.open("unsaved_confirmation", "res://scenes/interface/popups/UnsavedConfirmation.tscn")
		if popup:
			if not popup.confirmed.is_connected(_on_exit_confirmed):
				popup.confirmed.connect(_on_exit_confirmed)
	else:
		get_tree().quit()


func _on_exit_confirmed() -> void:
	get_tree().quit()


# ---------------------------------------------------------------------------
# Accessors (used by tools, actions, and rendering — require no changes there)
# ---------------------------------------------------------------------------

func get_current_document() -> ProjectDocument:
	if open_documents.is_empty():
		return null
	var idx := clampi(active_document_index, 0, open_documents.size() - 1)
	return open_documents[idx]


func get_current_sequence() -> DrawCommandSequence:
	var doc = get_current_document()
	if not doc:
		return null
	return doc.sequence


func get_current_image() -> DrawCommandImage:
	var seq := get_current_sequence()
	if seq == null:
		return null
	var frames := seq.frames
	var current_idx := EditorState.current_frame
	if current_idx < 0 or current_idx >= frames.size():
		return null
	return frames[current_idx]


func get_current_commands() -> Array:
	var image := get_current_image()
	if image == null:
		return []
	return image.commands


# ---------------------------------------------------------------------------
# Tab management
# ---------------------------------------------------------------------------

## Switches the active document tab. Resets the frame index and clears the
## selection so they are valid for the new document.
func set_active_sequence(index: int) -> void:
	if index < 0 or index >= open_documents.size():
		return
	if index == active_document_index:
		return
	active_document_index = index
	EditorState.set_current_frame(0)
	EditorState.clear_selection()
	data_changed.emit(true, -1)


## Adds a new sequence as a new tab and switches to it.
func add_sequence(seq: DrawCommandSequence, path: String = "") -> void:
	var doc = ProjectDocument.new()
	doc.sequence = seq
	doc.file_path = path
	doc.is_dirty = false
	doc.undo_redo = UndoRedo.new()
	doc.saved_history_version = 0
	open_documents.append(doc)
	active_document_index = open_documents.size() - 1
	EditorState.set_current_frame(0)
	EditorState.clear_selection()
	tab_list_changed.emit()
	# Use seq.frames.size() as affected_frame (always out-of-range for the new sequence)
	# so _on_data_changed clears the stale frame cache and triggers bulk rasterization
	# even when the new sequence has the same canvas layout as the previous one.
	data_changed.emit(true, seq.frames.size())


## Closes the tab at [param index]. The last tab cannot be closed.
## Emits tab_removed before tab_list_changed so listeners can free per-tab
## resources before the index shifts.
func close_sequence(index: int) -> void:
	if open_documents.size() <= 1:
		return
	if index < 0 or index >= open_documents.size():
		return
	open_documents.remove_at(index)
	if active_document_index >= open_documents.size():
		active_document_index = open_documents.size() - 1
	EditorState.set_current_frame(0)
	EditorState.clear_selection()
	tab_removed.emit(index)
	tab_list_changed.emit()
	data_changed.emit(true, -1)


## Replaces the entire workspace with a new set of sequences. Used by File → New.
func replace_sequences(seqs: Array[DrawCommandSequence], paths: Array[String]) -> void:
	open_documents.clear()
	for i in seqs.size():
		var doc = ProjectDocument.new()
		doc.sequence = seqs[i]
		doc.file_path = paths[i] if i < paths.size() else ""
		doc.is_dirty = false
		doc.undo_redo = UndoRedo.new()
		doc.saved_history_version = 0
		open_documents.append(doc)
	active_document_index = 0
	EditorState.set_current_frame(0)
	EditorState.clear_selection()
	tab_list_changed.emit()
	data_changed.emit(true, -1)


## Legacy: replaces the active tab's sequence in-place without structural tab changes.
func set_current_sequence(sequence: DrawCommandSequence) -> void:
	if open_documents.is_empty():
		var doc = ProjectDocument.new()
		doc.sequence = sequence
		doc.file_path = ""
		doc.is_dirty = false
		doc.undo_redo = UndoRedo.new()
		doc.saved_history_version = 0
		open_documents.append(doc)
		tab_list_changed.emit()
	else:
		var doc = get_current_document()
		if doc:
			doc.sequence = sequence
	data_changed.emit(true, -1)
