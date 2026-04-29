extends MenuBar

var file_items = [
	{"New": Fileman.open_file_dialog}

]



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	populate_menus()
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func populate_menus() -> void:
	var file_popup = $HBoxContainer/File.get_popup()
	var file_functions: Array[Callable]
	var current_id := 0
	for item in file_items:
		if not item.keys().size():
			continue
		
		file_popup.add_item(item.keys().front(),current_id)
		file_functions.append(item.values().front())
		
		current_id += 1
	file_popup.id_pressed.connect(func(id: int): file_functions[id].call())
