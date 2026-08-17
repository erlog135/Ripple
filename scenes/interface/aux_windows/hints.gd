extends Control

@onready var label: Label = $Panel/MarginContainer/Label

func _ready() -> void:
	EditorState.tool_changed.connect(_on_tool_updated)
	EditorState.selection_changed.connect(func(_by_user: bool): _on_tool_updated(EditorState.active_tool))
	_on_tool_updated(EditorState.active_tool)


func _on_tool_updated(tool: EditorState.Tool) -> void:
	match tool:
		EditorState.Tool.EDIT:
			if EditorState.selected_command_indices.is_empty():
				label.text = "Click to select. Double click to select whole shape. Click and drag to select a rectangular area."
			else:
				label.text = "Drag within the selection to move. Drag the edge handles to scale. Drag outside the edges to rotate."
		EditorState.Tool.LINE_PEN:
			label.text = "Click to place a point. If one is already selected, extend or close the shape. If two are selected, add point between them."
		EditorState.Tool.CIRCLE:
			label.text = "Click and drag to draw circle. Hold Alt to draw centered."
		EditorState.Tool.RECTANGLE:
			label.text = "Click and drag to draw rectangle. Hold Shift to draw a square. Hold Alt to draw centered."
		EditorState.Tool.PAN:
			label.text = "Click and drag to pan the view. Middle click dragging and scrolling to zoom always works."
		_:
			label.text = ""
