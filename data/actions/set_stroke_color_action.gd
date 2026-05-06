class_name SetStrokeColorAction
extends DrawCommandPropertyAction


func _init(frame_index: int, command_indices: Array[int], new_color: Color) -> void:
	super._init("Set Stroke Color", frame_index, command_indices, &"stroke_color", new_color)