extends Control

@onready var tool_list: ItemList = $ToolList

func _ready() -> void:
	for tool in EditorState.Tool.keys():
		tool_list.add_item(tool.capitalize())

	tool_list.item_selected.connect(_on_tool_selected)
	EditorState.tool_changed.connect(_on_editor_tool_changed)
	tool_list.select(EditorState.active_tool)

func _on_tool_selected(index: int) -> void:
	EditorState.change_tool(index)

func _on_editor_tool_changed(tool: EditorState.Tool) -> void:
	tool_list.select(tool)
