extends Control

const COLOR_POPUP_SCENE = "res://scenes/interface/popups/ColorPopup.tscn"

@onready var bg_color_rect: ColorRect = $Panel/MarginContainer/VBoxContainer/BackgroundColor/ColorRect

@onready var clip_bounds_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/ClipBoundsToggle
@onready var raster_preview_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/RasterPreviewToggle
@onready var resize_button: Button = $Panel/MarginContainer/VBoxContainer/ResizeButton

var _syncing := false

func _ready() -> void:
	
	#change the switch if rendermode gets set from somewhere else
	EditorState.render_mode_changed.connect(func(mode: EditorState.RenderMode): raster_preview_toggle.set_pressed_no_signal(mode == EditorState.RenderMode.RASTER))
	#same for bounds clipping
	EditorState.clip_to_bounds_changed.connect(func(enabled: bool): clip_bounds_toggle.set_pressed_no_signal(enabled))
	
	raster_preview_toggle.toggled.connect(func(toggled_on: bool): EditorState.set_render_mode(EditorState.RenderMode.RASTER if toggled_on else EditorState.RenderMode.VECTOR))
	clip_bounds_toggle.toggled.connect(func(toggled_on: bool): EditorState.clip_to_document_bounds = toggled_on)
	
	bg_color_rect.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_open_color_picker("color_picker_bg", bg_color_rect.color, _on_bg_color_selected))

func _open_color_picker(popup_id: String, current: Color, on_selected: Callable) -> void:
	var popup = PopupManager.open(popup_id, COLOR_POPUP_SCENE)
	if popup == null:
		return
	if not popup.color_selected.is_connected(on_selected):
		popup.color_selected.connect(on_selected)
	_syncing = true
	popup.select_color(current)
	_syncing = false

func _on_bg_color_selected(color: Color):
	pass
