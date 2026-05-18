class_name MenuCategoryButton
extends Button

signal menu_requested

var category_name: String = ""


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	pressed.connect(func(): menu_requested.emit())
