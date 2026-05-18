extends Control

const DROPDOWN_SCENE := preload("res://scenes/interface/menus/MenuDropdown.tscn")

@onready var _buttons_row: HBoxContainer = $HBoxContainer

var _dropdown: PopupPanel
var _open_category: String = ""


func _ready() -> void:
	_dropdown = DROPDOWN_SCENE.instantiate()
	add_child(_dropdown)
	_dropdown.closed.connect(_on_dropdown_closed)
	_build_category_buttons()


func _build_category_buttons() -> void:
	for child: Node in _buttons_row.get_children():
		child.queue_free()

	for category: String in MenuSchema.menu_data.keys():
		var button := MenuCategoryButton.new()
		button.category_name = category
		button.text = category.to_upper()
		button.menu_requested.connect(_on_category_requested.bind(category, button))
		_buttons_row.add_child(button)


func _on_category_requested(category: String, button: Button) -> void:
	if _dropdown.visible and _open_category == category:
		_dropdown.hide()
		return

	var items: Array = MenuSchema.menu_data.get(category, [])
	_dropdown.populate(items)
	_dropdown.open_below(button)
	_open_category = category


func _on_dropdown_closed() -> void:
	_open_category = ""
