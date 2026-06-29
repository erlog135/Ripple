extends Node

signal data_changed(by_user: bool, affected_frame: int)
## Emitted whenever the set of open tabs changes (add, close, replace).
signal tab_list_changed
## Emitted just before a tab is removed, so listeners (e.g. HistoryManager) can
## clean up per-tab state before the array shrinks. Index refers to the
## open_sequences position being removed.
signal tab_removed(index: int)

var open_sequences: Array[DrawCommandSequence] = []
var sequence_paths: Array[String] = []
var active_sequence_index: int = 0


# ---------------------------------------------------------------------------
# Backward-compatibility computed properties
# ---------------------------------------------------------------------------

## The currently active DrawCommandSequence. Read-only; use set_active_sequence
## or add_sequence to change which sequence is active.
var current_sequence: DrawCommandSequence:
	get: return get_current_sequence()

## The save path of the currently active tab.
## Writing to this updates the active tab's entry in sequence_paths.
var current_path: String:
	get:
		if sequence_paths.is_empty() or active_sequence_index >= sequence_paths.size():
			return ""
		return sequence_paths[active_sequence_index]
	set(value):
		if active_sequence_index >= 0 and active_sequence_index < sequence_paths.size():
			sequence_paths[active_sequence_index] = value


# ---------------------------------------------------------------------------
# Accessors (used by tools, actions, and rendering — require no changes there)
# ---------------------------------------------------------------------------

func get_current_sequence() -> DrawCommandSequence:
	if open_sequences.is_empty():
		return null
	var idx := clampi(active_sequence_index, 0, open_sequences.size() - 1)
	return open_sequences[idx]


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
## selection so they are always valid for the new document.
func set_active_sequence(index: int) -> void:
	if index < 0 or index >= open_sequences.size():
		return
	if index == active_sequence_index:
		return
	active_sequence_index = index
	EditorState.set_current_frame(0)
	EditorState.clear_selection()
	data_changed.emit(true, -1)


## Adds a new sequence as a new tab and switches to it.
func add_sequence(seq: DrawCommandSequence, path: String = "") -> void:
	open_sequences.append(seq)
	sequence_paths.append(path)
	active_sequence_index = open_sequences.size() - 1
	EditorState.set_current_frame(0)
	EditorState.clear_selection()
	tab_list_changed.emit()
	data_changed.emit(true, -1)


## Closes the tab at [param index]. The last tab cannot be closed.
## Emits tab_removed before tab_list_changed so listeners can free per-tab
## resources (e.g. HistoryManager's UndoRedo instance) before the index shifts.
func close_sequence(index: int) -> void:
	if open_sequences.size() <= 1:
		return
	if index < 0 or index >= open_sequences.size():
		return
	open_sequences.remove_at(index)
	sequence_paths.remove_at(index)
	if active_sequence_index >= open_sequences.size():
		active_sequence_index = open_sequences.size() - 1
	EditorState.set_current_frame(0)
	EditorState.clear_selection()
	tab_removed.emit(index)
	tab_list_changed.emit()
	data_changed.emit(true, -1)


## Replaces the entire workspace with a new set of sequences. Used by File → New.
## This is intentionally destructive: it does not emit tab_removed for old tabs
## because the caller (Fileman.new_file) is responsible for clearing history first.
func replace_sequences(seqs: Array[DrawCommandSequence], paths: Array[String]) -> void:
	open_sequences = seqs
	sequence_paths = paths
	active_sequence_index = 0
	EditorState.set_current_frame(0)
	EditorState.clear_selection()
	tab_list_changed.emit()
	data_changed.emit(true, -1)


## Legacy: replaces the active tab's sequence in-place without structural tab changes.
## Kept for backward compatibility with any residual callers; prefer add_sequence
## or replace_sequences for new code.
func set_current_sequence(sequence: DrawCommandSequence) -> void:
	if open_sequences.is_empty():
		open_sequences.append(sequence)
		sequence_paths.append("")
		tab_list_changed.emit()
	else:
		open_sequences[active_sequence_index] = sequence
	data_changed.emit(true, -1)
