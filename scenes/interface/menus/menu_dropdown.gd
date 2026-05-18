extends PopupPanel

signal item_pressed(action_id: String)
signal closed

const ITEM_SCENE := preload("res://scenes/interface/menus/CustomMenuItem.tscn")

@onready var _items_box: VBoxContainer = $Margin/VBox


func _ready() -> void:
	popup_hide.connect(func(): closed.emit())


func populate(items: Array) -> void:
	for child: Node in _items_box.get_children():
		child.queue_free()

	for item_data: Dictionary in items:
		var menu_item: PanelContainer = ITEM_SCENE.instantiate()
		_items_box.add_child(menu_item)
		menu_item.setup(item_data)
		menu_item.item_pressed.connect(_on_item_pressed)


func open_below(anchor: Control) -> void:
	var pos := anchor.global_position + Vector2(0, anchor.size.y)
	popup(Rect2i(Vector2i(pos), Vector2i.ZERO))


func _on_item_pressed(action_id: String) -> void:
	item_pressed.emit(action_id)
	hide()
