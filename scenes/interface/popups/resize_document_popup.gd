extends Window

## Controller for the "Resize Document Bounds" dialog. Collects the target size and
## the 9-point content anchor, then commits a ResizeDocumentAction through the undo
## stack. The view never mutates project data directly (MVC): it only gathers input.

@onready var image_width: SpinBox = $Panel/VBoxContainer/Width/ImageWidth
@onready var image_height: SpinBox = $Panel/VBoxContainer/Height/ImageHeight
@onready var keep_aspect_toggle: CheckButton = $Panel/VBoxContainer/KeepAspectToggle

@onready var top_left: Button = $Panel/VBoxContainer/ButtonGrid/TopLeft
@onready var top_middle: Button = $Panel/VBoxContainer/ButtonGrid/TopMiddle
@onready var top_right: Button = $Panel/VBoxContainer/ButtonGrid/TopRight
@onready var left: Button = $Panel/VBoxContainer/ButtonGrid/Left
@onready var middle: Button = $Panel/VBoxContainer/ButtonGrid/Middle
@onready var right: Button = $Panel/VBoxContainer/ButtonGrid/Right
@onready var bottom_left: Button = $Panel/VBoxContainer/ButtonGrid/BottomLeft
@onready var bottom_middle: Button = $Panel/VBoxContainer/ButtonGrid/BottomMiddle
@onready var bottom_right: Button = $Panel/VBoxContainer/ButtonGrid/BottomRight

@onready var resize_button: Button = $Panel/ResizeButton
@onready var cancel_button: Button = $Panel/CancelButton

## Width / height ratio captured on open; drives the "Keep aspect" linkage.
var _original_ratio: float = 1.0
## Guards against the value_changed feedback loop when one box updates the other.
var _is_updating: bool = false
## Maps each anchor button to its content-stick percentage (0.0 / 0.5 / 1.0).
var _anchor_buttons: Dictionary = {}


func _ready() -> void:
	borderless = false
	exclusive = true

	_configure_spinbox(image_width)
	_configure_spinbox(image_height)
	_setup_anchor_buttons()

	var current_size := _current_document_size()
	_original_ratio = float(current_size.x) / float(current_size.y) if current_size.y != 0 else 1.0

	_is_updating = true
	image_width.value = current_size.x
	image_height.value = current_size.y
	_is_updating = false

	image_width.value_changed.connect(_on_width_changed)
	image_height.value_changed.connect(_on_height_changed)
	resize_button.pressed.connect(_on_resize_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	close_requested.connect(queue_free)


func _configure_spinbox(box: SpinBox) -> void:
	box.min_value = 1
	box.max_value = 65535
	box.step = 1
	box.rounded = true


## Turns the 9 grid buttons into a single radio group (only one pressed at a time),
## tags each with its anchor percentage, and selects the center by default.
func _setup_anchor_buttons() -> void:
	_anchor_buttons = {
		top_left: Vector2(0.0, 0.0),
		top_middle: Vector2(0.5, 0.0),
		top_right: Vector2(1.0, 0.0),
		left: Vector2(0.0, 0.5),
		middle: Vector2(0.5, 0.5),
		right: Vector2(1.0, 0.5),
		bottom_left: Vector2(0.0, 1.0),
		bottom_middle: Vector2(0.5, 1.0),
		bottom_right: Vector2(1.0, 1.0),
	}

	var group := ButtonGroup.new()
	for button: Button in _anchor_buttons:
		button.toggle_mode = true
		button.button_group = group

	middle.button_pressed = true


func _current_document_size() -> Vector2i:
	var image := ProjectData.get_current_image()
	if image == null or image.bounds.x <= 0 or image.bounds.y <= 0:
		return Vector2i(64, 64)
	return image.bounds


## The percentage of the selected anchor; defaults to center if somehow none is set.
func _selected_anchor() -> Vector2:
	for button: Button in _anchor_buttons:
		if button.button_pressed:
			return _anchor_buttons[button]
	return Vector2(0.5, 0.5)


func _on_width_changed(value: float) -> void:
	if _is_updating or not keep_aspect_toggle.button_pressed:
		return
	_is_updating = true
	image_height.value = maxf(1.0, round(value / _original_ratio))
	_is_updating = false


func _on_height_changed(value: float) -> void:
	if _is_updating or not keep_aspect_toggle.button_pressed:
		return
	_is_updating = true
	image_width.value = maxf(1.0, round(value * _original_ratio))
	_is_updating = false


func _on_resize_pressed() -> void:
	var target_size := Vector2i(int(image_width.value), int(image_height.value))
	if target_size != _current_document_size():
		HistoryManager.commit(ResizeDocumentAction.new(target_size, _selected_anchor()))
	queue_free()


func _on_cancel_pressed() -> void:
	queue_free()
