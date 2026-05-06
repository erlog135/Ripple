class_name SetDrawCommandPointsAction
extends DrawCommandPropertyAction


## Assigns packed point arrays per selected command.[br]
## [param new_points_arrays] aligns with [param command_indices] (same length, same order).


func _init(frame_index: int, command_indices: Array[int], new_points_arrays: Array) -> void:
	super._init(
		"Set Points",
		frame_index,
		command_indices,
		&"points",
		null,
		new_points_arrays,
	)