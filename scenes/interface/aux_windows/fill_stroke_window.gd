extends Control

const COLOR_POPUP = preload("uid://opfiwgeouvns")
@onready var fill_rect: ColorRect = $Panel/Options/FillColor/ColorRect
@onready var stroke_rect: ColorRect = $Panel/Options/StrokeColor/ColorRect

var fill_popup: PopupPanel
var stroke_popup: PopupPanel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	fill_popup = COLOR_POPUP.instantiate()
	fill_popup.color_selected.connect(func(color: Color):
		fill_rect.color = color)
	fill_rect.add_child(fill_popup)
	fill_rect.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			fill_popup.popup_centered())


	stroke_popup = COLOR_POPUP.instantiate()
	stroke_popup.color_selected.connect(func(color: Color):
		stroke_rect.color = color)
	stroke_rect.add_child(stroke_popup)
	stroke_rect.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			stroke_popup.popup_centered())




# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
