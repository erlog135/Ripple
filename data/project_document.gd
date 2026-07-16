class_name ProjectDocument
extends RefCounted

var sequence: DrawCommandSequence
var file_path: String = ""
var is_dirty: bool = false

# EACH document gets its own Undo/Redo stack!
var undo_redo: UndoRedo = UndoRedo.new()
var saved_history_version: int = 0

func get_file_name() -> String:
	if file_path == "":
		return "Untitled"
	return file_path.get_file().get_basename()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if undo_redo:
			undo_redo.free()
