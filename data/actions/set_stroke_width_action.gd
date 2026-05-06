class_name SetStrokeWidthAction
extends DrawCommandPropertyAction


func _init(frame_index: int, command_indices: Array[int], new_width: int) -> void:
	super._init("Set Stroke Width", frame_index, command_indices, &"stroke_width", new_width)