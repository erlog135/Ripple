extends Control

@onready var tool_list: ItemList = $Panel/MarginContainer/VBoxContainer/ToolList
@onready var tool_description: RichTextLabel = $Panel/MarginContainer/VBoxContainer/ToolDescription


const TOOL_CIRCLE = preload("uid://buco5y6muxvhn")
const TOOL_LINE_PEN = preload("uid://c1epqd3vwb1b5")
const TOOL_PAN = preload("uid://mh3kx6yvter7")
const TOOL_RECTANGLE = preload("uid://dy4p0t40vnyy2")
const TOOL_EDIT = preload("uid://0g8p7lvto7v8")


const TOOL_ICONS: Dictionary[EditorState.Tool,Resource] = {
	EditorState.Tool.EDIT: TOOL_EDIT,
	EditorState.Tool.LINE_PEN: TOOL_LINE_PEN,
	EditorState.Tool.CIRCLE: TOOL_CIRCLE,
	EditorState.Tool.RECTANGLE: TOOL_RECTANGLE,
	EditorState.Tool.PAN: TOOL_PAN,
}

const TOOL_DESCRIPTIONS: Dictionary[EditorState.Tool, String] = {
	EditorState.Tool.EDIT: "[b]Edit[/b] (E)\n[color=#a0a0a0]Click to select. Double click to select whole shape. Click and drag to select a rectangular area.\nDrag within the selection to move, edge handles to scale, or outside the edges to rotate.[/color]",
	EditorState.Tool.LINE_PEN: "[b]Line Pen[/b] (L)\n[color=#a0a0a0]Click to place a point. If one is already selected, extend or close the shape. If two are selected, add point between them.[/color]",
	EditorState.Tool.CIRCLE: "[b]Circle[/b] (C)\n[color=#a0a0a0]Click and drag to draw circle. Hold Alt to draw centered.[/color]",
	EditorState.Tool.RECTANGLE: "[b]Rectangle[/b] (R)\n[color=#a0a0a0]Click and drag to draw rectangle. Hold Shift to draw a square. Hold Alt to draw centered.[/color]",
	EditorState.Tool.PAN: "[b]Pan[/b] (P)\n[color=#a0a0a0]Click and drag to pan the view. Middle click dragging and scrolling to zoom always works.[/color]",
}

func _ready() -> void:
	tool_description.bbcode_enabled = true
	for tool in EditorState.Tool.keys():
		tool_list.add_item("",TOOL_ICONS[EditorState.Tool[tool]])

	tool_list.item_selected.connect(_on_tool_selected)
	EditorState.tool_changed.connect(_on_editor_tool_changed)
	tool_list.select(EditorState.active_tool)
	_update_tool_description(EditorState.active_tool)

func _on_tool_selected(index: int) -> void:
	EditorState.change_tool(index)

func _on_editor_tool_changed(tool: EditorState.Tool) -> void:
	tool_list.select(tool)
	_update_tool_description(tool)

func _update_tool_description(tool: EditorState.Tool) -> void:
	tool_description.text = TOOL_DESCRIPTIONS.get(tool, "")
