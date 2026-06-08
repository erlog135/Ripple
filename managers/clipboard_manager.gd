extends Node

## Holds copied draw commands and bridges the user's selection (EditorState) with
## the undo stack (HistoryManager) for Cut/Copy/Paste.
##
## Everything stored and handed out is a deep clone: copying takes snapshots that
## won't change if the originals are later edited, and pasting hands out fresh
## copies so the same clipboard contents can be pasted repeatedly.

const PASTE_OFFSET := Vector2(8.0, 8.0)

var _copied_commands: Array[DrawCommand] = []
## Frame the data was copied from; drives smart paste offsetting.
var _source_frame_index: int = -1


## Ctrl+C: snapshot the currently selected commands (layers).
func copy_selection() -> void:
	var indices := EditorState.selected_command_indices
	if indices.is_empty():
		return

	var commands := ProjectData.get_current_commands()
	_copied_commands.clear()
	# Copy in ascending index order so paste order matches the layer stack.
	var sorted := indices.duplicate()
	sorted.sort()
	for idx: int in sorted:
		if idx < 0 or idx >= commands.size():
			continue
		_copied_commands.append((commands[idx] as DrawCommand).clone())
	_source_frame_index = EditorState.current_frame


## Ctrl+X: copy, then delete the selected commands through the undo stack.
func cut_selection() -> void:
	var indices := EditorState.selected_command_indices
	if indices.is_empty():
		return
	copy_selection()
	HistoryManager.commit(DeleteCommandsAction.new(EditorState.current_frame, indices))


func has_data() -> bool:
	return not _copied_commands.is_empty()


## Hands out fresh deep copies so callers (PasteAction) never share references
## with the clipboard or with each other.
func get_paste_data() -> Array[DrawCommand]:
	var clones: Array[DrawCommand] = []
	for cmd in _copied_commands:
		clones.append(cmd.clone())
	return clones


## Ctrl+D: clone the current selection and paste it offset on the same frame,
## without touching the clipboard contents.
func duplicate_selection() -> void:
	var indices := EditorState.selected_command_indices
	if indices.is_empty():
		return

	var commands := ProjectData.get_current_commands()
	var clones: Array[DrawCommand] = []
	var sorted := indices.duplicate()
	sorted.sort()
	for idx: int in sorted:
		if idx < 0 or idx >= commands.size():
			continue
		clones.append((commands[idx] as DrawCommand).clone())
	if clones.is_empty():
		return

	var action := PasteAction.new(PASTE_OFFSET, clones)
	action.action_name = "Duplicate"
	HistoryManager.commit(action)


## Ctrl+V: paste through the undo stack. Pasting back onto the source frame nudges
## the result so the user sees it; pasting onto a different frame keeps it in place
## (important for animation, so shapes don't drift between frames).
func paste() -> void:
	if not has_data():
		return
	var offset := PASTE_OFFSET if _source_frame_index == EditorState.current_frame else Vector2.ZERO
	HistoryManager.commit(PasteAction.new(offset))
