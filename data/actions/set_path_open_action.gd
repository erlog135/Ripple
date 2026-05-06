class_name SetPathOpenAction
extends DrawCommandPropertyAction


func _init(frame_index: int, command_indices: Array[int], path_open: bool) -> void:
	super._init("Set Path Open", frame_index, command_indices, &"path_open", path_open)
