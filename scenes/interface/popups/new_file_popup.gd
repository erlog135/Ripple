extends Popup

## Controller for the "New Image" dialog. Gathers the requested dimensions and
## hands them to Fileman; it never touches project data directly (MVC: the view
## collects input, the manager performs the destructive reset).

@onready var image_width: SpinBox = $Panel/VBoxContainer/HBoxContainer/ImageWidth
@onready var image_height: SpinBox = $Panel/VBoxContainer/HBoxContainer2/ImageHeight
@onready var create_button: Button = $Panel/CreateButton
@onready var cancel_button: Button = $Panel/CancelButton


func _ready() -> void:
	borderless = false
	exclusive = true
	create_button.pressed.connect(_on_create_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	popup_hide.connect(queue_free)


func _on_create_pressed() -> void:
	var new_size := Vector2i(int(image_width.value), int(image_height.value))
	Fileman.new_file(new_size)
	queue_free()


func _on_cancel_pressed() -> void:
	queue_free()
