extends Control

const COLOR_POPUP_SCENE = "res://scenes/interface/popups/ColorPopup.tscn"

@onready var bg_color_rect: ColorRect = $Panel/MarginContainer/VBoxContainer/BackgroundRect
@onready var bg_color_label: Label = $Panel/MarginContainer/VBoxContainer/BackgroundRect/Label

@onready var snapping_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/SnappingToggle
@onready var clip_bounds_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/ClipBoundsToggle
@onready var raster_preview_toggle: CheckButton = $Panel/MarginContainer/VBoxContainer/RasterPreviewToggle
@onready var resize_button: Button = $Panel/MarginContainer/VBoxContainer/ResizeButton

var _syncing := false

func _ready() -> void:
	
	#change the switch if rendermode gets set from somewhere else
	EditorState.render_mode_changed.connect(func(mode: EditorState.RenderMode): raster_preview_toggle.set_pressed_no_signal(mode == EditorState.RenderMode.RASTER))
	#same for bounds clipping
	EditorState.clip_to_bounds_changed.connect(func(enabled: bool): clip_bounds_toggle.set_pressed_no_signal(enabled))
	EditorState.grid_snap_changed.connect(func(enabled: bool): snapping_toggle.set_pressed_no_signal(enabled))
	EditorState.bg_color_changed.connect(_sync_from_editor_state)
	
	raster_preview_toggle.toggled.connect(func(toggled_on: bool): EditorState.set_render_mode(EditorState.RenderMode.RASTER if toggled_on else EditorState.RenderMode.VECTOR))
	snapping_toggle.toggled.connect(func(toggled_on: bool): EditorState.grid_snap = toggled_on)
	clip_bounds_toggle.toggled.connect(func(toggled_on: bool): EditorState.clip_to_document_bounds = toggled_on)
	
	raster_preview_toggle.set_pressed_no_signal(EditorState.render_mode == EditorState.RenderMode.RASTER)
	snapping_toggle.set_pressed_no_signal(EditorState.grid_snap)
	clip_bounds_toggle.set_pressed_no_signal(EditorState.clip_to_document_bounds)
	
	bg_color_rect.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_open_color_picker("color_picker_bg", bg_color_rect.color, _on_bg_color_selected))
	

	
	resize_button.pressed.connect(func(): PopupManager.open("resize_document", "res://scenes/interface/popups/ResizeDocumentPopup.tscn"))
	_sync_from_editor_state()


func _sync_from_editor_state() -> void:
	if _syncing:
		return
	_syncing = true
	_update_bg_ui(EditorState.current_bg_color)
	_syncing = false


func _update_bg_ui(color: Color) -> void:
	bg_color_rect.color = color
	var color_name: String = GColor.COLOR_NAMES.get(color, "Custom")
	bg_color_label.text = "BG: %s" % color_name
	bg_color_label.add_theme_color_override("font_color", GColor.legible_over(color))


func _open_color_picker(popup_id: String, current: Color, on_selected: Callable) -> void:
	var popup = PopupManager.open(popup_id, COLOR_POPUP_SCENE)
	if popup == null:
		return
	if not popup.color_selected.is_connected(on_selected):
		popup.color_selected.connect(on_selected)
	_syncing = true
	popup.select_color(current)
	_syncing = false


func _on_bg_color_selected(color: Color) -> void:
	_update_bg_ui(color)
	EditorState.set_current_bg_color(color)
