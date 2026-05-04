extends MenuBar

var file_items = [
	{"New": Fileman.open_file_dialog}

]

var edit_items = [
	{"Undo": HistoryManager.undo},
	{"Redo": HistoryManager.redo},
	{"Select All": EditorState.select_all},
	{"Deselect": EditorState.deselect_all}
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	populate_menus()
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Helper to setup a popup with items and functions
func populate_popup_with_items(popup: PopupMenu, items: Array) -> void:
	var functions: Array[Callable] = []
	var current_id := 0
	for item in items:
		if not item.keys().size():
			continue
		popup.add_item(item.keys().front(), current_id)
		functions.append(item.values().front())
		current_id += 1
	popup.id_pressed.connect(func(id: int): functions[id].call())

func populate_menus() -> void:
	populate_popup_with_items($HBoxContainer/File.get_popup(), file_items)
	populate_popup_with_items($HBoxContainer/Edit.get_popup(), edit_items)
