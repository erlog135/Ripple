extends Control

@onready var tool_list: ItemList = $ToolList

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	tool_list.item_selected.connect(_on_tool_selected)
	tool_list.select(0)

func _on_tool_selected(index: int) -> void:
	EditorState.change_tool(index)
