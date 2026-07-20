extends Control

## Emitted when the user clicks the tab body to switch to this document.
signal tab_clicked(index: int)
## Emitted when the user clicks the close button on this tab.
signal tab_closed(index: int)

@onready var texture_rect: TextureRect = $TextureRect
@onready var selector_rect: ReferenceRect = $SelectorRect
@onready var unsaved_indicator: Label = $UnsavedIndicator
@onready var name_label: Label = $NameLabel
@onready var close_button: TextureButton = $CloseButton

var _index: int = 0


func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	gui_input.connect(_on_gui_input)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Configures the tab widget. Call once after instantiating from DocumentTabs.
## [param index]     position in ProjectData.open_sequences
## [param seq]       the DrawCommandSequence this tab represents
## [param is_active] whether this is the currently selected tab
## [param is_unsaved] whether the sequence has unsaved changes (shows " *")
func setup(index: int, seq: DrawCommandSequence, is_active: bool, is_unsaved: bool) -> void:
	_index = index

	# Size label from first frame bounds.
	if seq != null and not seq.frames.is_empty():
		var bounds: Vector2i = seq.frames[0].bounds
		name_label.text = "%d×%d" % [bounds.x, bounds.y]  # e.g. "25×25"
	else:
		name_label.text = "Empty"

	set_active(is_active)
	unsaved_indicator.visible = is_unsaved

	# Thumbnail from render cache; may be null if this tab hasn't been rendered yet.
	if seq != null and not seq.frames.is_empty():
		texture_rect.texture = RenderManager.get_image_texture(seq.frames[0])
	else:
		texture_rect.texture = null


## Updates the selection highlight ring without rebuilding the whole tab.
func set_active(active: bool) -> void:
	selector_rect.visible = active


## Replaces the thumbnail texture, called on data_changed while this is the active tab.
## Only updates when [param tex] is non-null, matching FrameItem behaviour — a previously
## displayed thumbnail persists while rasterization is in progress rather than blanking out.
func update_thumbnail(tex: ImageTexture) -> void:
	if tex != null:
		texture_rect.texture = tex


## Updates the stored index. Called by DocumentTabs after a tab is closed to
## re-sequence the remaining tabs without a full rebuild.
func set_index(new_index: int) -> void:
	_index = new_index


## Updates the unsaved indicator visibility dynamically.
func set_unsaved(unsaved: bool) -> void:
	unsaved_indicator.visible = unsaved


func _on_close_button_pressed() -> void:
	tab_closed.emit(_index)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			tab_clicked.emit(_index)
			accept_event()
