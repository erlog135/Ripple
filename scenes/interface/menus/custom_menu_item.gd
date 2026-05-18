extends PanelContainer

signal item_pressed(action_id: String)

const ITEM_SCENE := preload("res://scenes/interface/menus/CustomMenuItem.tscn")
const SUBMENU_HOVER_DELAY := 0.15

var item_data: Dictionary = {}

@onready var _row: HBoxContainer = $Row
@onready var _check_icon: Label = $Row/CheckIcon
@onready var _main_icon: TextureRect = $Row/MainIcon
@onready var _label: Label = $Row/Label
@onready var _shortcut_text: Label = $Row/ShortcutText
@onready var _submenu_arrow: Label = $Row/SubmenuArrow
@onready var _separator: HSeparator = $Separator
@onready var _submenu_dropdown: PanelContainer = $SubmenuDropdown

var _submenu_hide_timer: Timer
var _submenu_items: Array[Node] = []
var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	MenuDispatcher.menu_state_changed.connect(_update_check_state)

	_normal_style = get_theme_stylebox("panel") as StyleBoxFlat
	if _normal_style:
		_hover_style = _normal_style.duplicate() as StyleBoxFlat
		_hover_style.bg_color = Color(0.26, 0.26, 0.32, 1)

	_submenu_hide_timer = Timer.new()
	_submenu_hide_timer.one_shot = true
	_submenu_hide_timer.wait_time = SUBMENU_HOVER_DELAY
	_submenu_hide_timer.timeout.connect(_hide_submenu)
	add_child(_submenu_hide_timer)

	_submenu_dropdown.top_level = true
	_submenu_dropdown.visible = false
	_submenu_dropdown.mouse_entered.connect(_on_submenu_mouse_entered)
	_submenu_dropdown.mouse_exited.connect(_on_submenu_mouse_exited)


func _exit_tree() -> void:
	if MenuDispatcher.menu_state_changed.is_connected(_update_check_state):
		MenuDispatcher.menu_state_changed.disconnect(_update_check_state)


func setup(data: Dictionary) -> void:
	item_data = data
	var item_type: String = data.get("type", "action")

	if item_type == "separator":
		_row.visible = false
		_separator.visible = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.y = 9
		return

	_row.visible = true
	_separator.visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	_label.text = data.get("label", "")
	_submenu_arrow.visible = item_type == "submenu"

	if data.has("icon"):
		_main_icon.texture = load(data["icon"]) as Texture2D
		_main_icon.visible = _main_icon.texture != null
	else:
		_main_icon.visible = false

	var is_toggle := item_type == "checkbox" or item_type == "radio"
	_check_icon.visible = is_toggle

	if data.has("shortcut"):
		var sc: Shortcut = data["shortcut"]
		_shortcut_text.text = sc.get_as_text()
		_shortcut_text.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	else:
		_shortcut_text.text = ""

	if item_type == "submenu":
		_build_submenu(data.get("children", []))

	_update_check_state()


func _build_submenu(children: Array) -> void:
	for child: Node in _submenu_items:
		child.queue_free()
	_submenu_items.clear()

	var box := _submenu_dropdown.get_node("VBox") as VBoxContainer
	for child: Node in box.get_children():
		child.queue_free()

	for child_data: Dictionary in children:
		var child_item: PanelContainer = ITEM_SCENE.instantiate()
		box.add_child(child_item)
		child_item.setup(child_data)
		child_item.item_pressed.connect(_on_submenu_item_pressed)
		_submenu_items.append(child_item)


func _update_check_state() -> void:
	if item_data.is_empty():
		return
	var item_type: String = item_data.get("type", "")
	if item_type != "checkbox" and item_type != "radio":
		return
	if not item_data.has("id"):
		return

	var is_active := MenuDispatcher.get_state(item_data["id"])
	if item_type == "checkbox":
		_check_icon.text = "✓" if is_active else ""
	elif item_type == "radio":
		_check_icon.text = "●" if is_active else ""


func _on_gui_input(event: InputEvent) -> void:
	if item_data.get("type", "") == "separator":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if item_data.get("type", "") == "submenu":
			_show_submenu()
			return
		if item_data.has("id"):
			item_pressed.emit(item_data["id"])
			MenuDispatcher.execute(item_data["id"])


func _on_submenu_item_pressed(action_id: String) -> void:
	item_pressed.emit(action_id)


func _on_mouse_entered() -> void:
	if item_data.get("type", "") == "separator":
		return
	if _hover_style:
		add_theme_stylebox_override("panel", _hover_style)
	if item_data.get("type", "") == "submenu":
		_submenu_hide_timer.stop()
		_show_submenu()


func _on_mouse_exited() -> void:
	if item_data.get("type", "") == "separator":
		return
	if _normal_style:
		add_theme_stylebox_override("panel", _normal_style)
	if item_data.get("type", "") == "submenu":
		_submenu_hide_timer.start()


func _on_submenu_mouse_entered() -> void:
	_submenu_hide_timer.stop()


func _on_submenu_mouse_exited() -> void:
	_submenu_hide_timer.start()


func _show_submenu() -> void:
	if item_data.get("type", "") != "submenu":
		return
	_submenu_dropdown.global_position = global_position + Vector2(size.x - 2, 0)
	_submenu_dropdown.visible = true


func _hide_submenu() -> void:
	_submenu_dropdown.visible = false


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not item_data.has("id"):
		return null
	var preview := Label.new()
	preview.text = item_data.get("label", "")
	set_drag_preview(preview)
	return {"action_id": item_data["id"]}
