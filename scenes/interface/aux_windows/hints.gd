extends Control

@onready var label: Label = $Panel/MarginContainer/Label

func _ready() -> void:
	EditorState.tool_changed.connect(_on_tool_updated)
	_on_tool_updated(EditorState.active_tool)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_tool_updated(tool: EditorState.Tool) -> void:
	match tool:
		EditorState.Tool.SELECT:
			label.text = "Click to select. Click and drag to select a rectangular area. Double click a selection to switch to Transform."
		EditorState.Tool.TRANSFORM:
			label.text = "Drag within the selection to move. Drag the edge handles to scale. Drag outside the edges to rotate. Double click a selection to switch to Select."
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
