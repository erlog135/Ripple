extends Node

var undo_redo := UndoRedo.new()

func undo() -> void:
	undo_redo.undo()

func redo() -> void:
	undo_redo.redo()
