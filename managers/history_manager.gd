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


func undo() -> void:
	if undo_redo.has_undo():
		undo_redo.undo()


func redo() -> void:
	if undo_redo.has_redo():
		undo_redo.redo()
