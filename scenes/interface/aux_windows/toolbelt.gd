extends Control

@onready var new_file_button: Button = $NewFileButton
@onready var open_file_button: Button = $OpenFileButton
@onready var save_file_button: Button = $SaveFileButton
@onready var cut_button: Button = $CutButton
@onready var copy_button: Button = $CopyButton
@onready var paste_button: Button = $PasteButton
@onready var undo_button: Button = $UndoButton
@onready var redo_button: Button = $RedoButton
@onready var zoom_fit_button: Button = $ZoomButton
   

func _ready() -> void:
	new_file_button.pressed.connect(func(): PopupManager.open("new_file", "res://scenes/interface/popups/NewFilePopup.tscn"))
	open_file_button.pressed.connect(func(): Fileman.open_file_dialog())
	save_file_button.pressed.connect(func(): Fileman.save_file())
	cut_button.pressed.connect(func(): ClipboardManager.cut_selection())
	copy_button.pressed.connect(func(): ClipboardManager.copy_selection())
	paste_button.pressed.connect(func(): ClipboardManager.paste())
	undo_button.pressed.connect(func(): HistoryManager.undo())
	redo_button.pressed.connect(func(): HistoryManager.redo())
	zoom_fit_button.pressed.connect(func(): EditorState.zoom_to_document(EditorState.canvas_viewport_size))

	new_file_button.tooltip_text = "New File"
	open_file_button.tooltip_text = "Open File"
	save_file_button.tooltip_text = "Save File"
	cut_button.tooltip_text = "Cut"
	copy_button.tooltip_text = "Copy"
	paste_button.tooltip_text = "Paste"
	undo_button.tooltip_text = "Undo"
	redo_button.tooltip_text = "Redo"
	zoom_fit_button.tooltip_text = "Zoom to Fit"
