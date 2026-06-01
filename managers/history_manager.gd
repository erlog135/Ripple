extends Node

const _EditAction = preload("res://data/actions/edit_action.gd")

var undo_redo := UndoRedo.new()


func commit(action: _EditAction, merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE) -> void:
	undo_redo.create_action(action.action_name, merge_mode)
	var do_call := Callable(action, &"do_action")
	var undo_call := Callable(action, &"undo_action")
	undo_redo.add_do_method(do_call)
	undo_redo.add_undo_method(undo_call)
	undo_redo.add_do_reference(action)
	undo_redo.add_undo_reference(action)
	undo_redo.commit_action()


## Wipes the entire undo/redo stack. Used by destructive operations such as
## creating a brand-new project, where prior history no longer makes sense.
func clear() -> void:
	undo_redo.clear_history()


func undo() -> void:
	if undo_redo.has_undo():
		undo_redo.undo()


func redo() -> void:
	if undo_redo.has_redo():
		undo_redo.redo()
