extends Control

@onready var tool_list: ItemList = $ToolList

const TOOL_CIRCLE = preload("uid://buco5y6muxvhn")
const TOOL_LINE_PEN = preload("uid://c1epqd3vwb1b5")
const TOOL_PAN = preload("uid://mh3kx6yvter7")
const TOOL_RECTANGLE = preload("uid://dy4p0t40vnyy2")
const TOOL_SELECT = preload("uid://0g8p7lvto7v8")
const TOOL_TRANSFORM = preload("uid://b0w4xtlid8vne")


const TOOL_ICONS: Dictionary[EditorState.Tool,Resource] = {
	EditorState.Tool.SELECT: TOOL_SELECT,
	EditorState.Tool.TRANSFORM: TOOL_TRANSFORM,
	EditorState.Tool.LINE_PEN: TOOL_LINE_PEN,
	EditorState.Tool.CIRCLE: TOOL_CIRCLE,
	EditorState.Tool.RECTANGLE: TOOL_RECTANGLE,
	EditorState.Tool.PAN: TOOL_PAN,
}

func _ready() -> void:
	for tool in EditorState.Tool.keys():
		tool_list.add_item(tool.capitalize(),TOOL_ICONS[EditorState.Tool[tool]])

	tool_list.item_selected.connect(_on_tool_selected)
	EditorState.tool_changed.connect(_on_editor_tool_changed)
	tool_list.select(EditorState.active_tool)

func _on_tool_selected(index: int) -> void:
	EditorState.change_tool(index)

func _on_editor_tool_changed(tool: EditorState.Tool) -> void:
	tool_list.select(tool)
