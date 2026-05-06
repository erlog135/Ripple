class_name SetFillColorAction
extends DrawCommandPropertyAction


func _init(frame_index: int, command_indices: Array[int], new_color: Color) -> void:
	super._init("Set Fill Color", frame_index, command_indices, &"fill_color", new_color)