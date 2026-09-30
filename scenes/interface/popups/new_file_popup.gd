extends Window

## Dialog controller for creating a new document. Gathers the requested dimensions
## and passes them to Fileman to open a new document tab.

@onready var image_width: SpinBox = $Panel/VBoxContainer/HBoxContainer/ImageWidth
@onready var image_height: SpinBox = $Panel/VBoxContainer/HBoxContainer2/ImageHeight
@onready var create_button: Button = $Panel/CreateButton
@onready var cancel_button: Button = $Panel/CancelButton


func _ready() -> void:
	borderless = false
	exclusive = true
	create_button.pressed.connect(_on_create_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	close_requested.connect(queue_free)

	# Release focus when Enter is pressed so global canvas shortcuts remain active.
	_connect_spinbox_enter_release(image_width)
	_connect_spinbox_enter_release(image_height)


func _on_create_pressed() -> void:
	var new_size := Vector2i(int(image_width.value), int(image_height.value))
	Fileman.new_file(new_size)
	queue_free()


func _on_cancel_pressed() -> void:
	queue_free()


## Connects the internal LineEdit of [param box] so pressing Enter releases focus,
## returning keyboard focus to the main canvas shortcuts.
func _connect_spinbox_enter_release(box: SpinBox) -> void:
	var le := box.get_line_edit()
	if le != null and not le.text_submitted.is_connected(_on_spinbox_text_submitted):
		le.text_submitted.connect(_on_spinbox_text_submitted.bind(le))


func _on_spinbox_text_submitted(_new_text: String, le: LineEdit) -> void:
	le.release_focus()
