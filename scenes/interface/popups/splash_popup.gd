extends Window

## Controller for the Welcome / Splash screen shown on first launch.
##
## MVC separation: this node is purely View + Controller. It collects the
## user's choice and forwards it to the appropriate manager:
##   - Fileman.new_file()      → blank document of a preset size
##   - Fileman.pdc_to_gd()    → load an example PDC from res://test/pdc/
##   - Fileman.load_project() → load a recent project file
##   - PopupManager.open()    → open the custom-size "New File" dialog
##
## No ProjectData, EditorState, or DrawCommandSequence access here.

const NEW_FILE_POPUP := "res://scenes/interface/popups/NewFilePopup.tscn"

# Example PDC files bundled with the project.
# Update these paths when the final examples are chosen.
const EXAMPLE_PATHS := [
	"res://test/pdc/confirm_sequence.pdc",
	"res://test/pdc/mute_sequence.pdc",
	"res://test/pdc/Weather_50px.pdc",
	"res://test/pdc/Bell_25px.pdc",
]

@onready var new_file_button: Button  = $Control/Start/NewFileButton
@onready var blank_25_button: Button  = $Control/Start/Blank25Button
@onready var blank_50_button: Button  = $Control/Start/Blank50Button
@onready var blank_80_button: Button  = $Control/Start/Blank80Button

@onready var example_1_button: Button = $Control/Examples/Example1Button
@onready var example_2_button: Button = $Control/Examples/Example2Button
@onready var example_3_button: Button = $Control/Examples/Example3Button
@onready var example_4_button: Button = $Control/Examples/Example4Button

@onready var recent_files: ItemList = $Control/Recent/ItemList


func _ready() -> void:
	exclusive = true
	close_requested.connect(queue_free)

	# --- Get Started column ---
	new_file_button.pressed.connect(_on_new_file_pressed)
	blank_25_button.pressed.connect(_on_blank_pressed.bind(Vector2i(25, 25)))
	blank_50_button.pressed.connect(_on_blank_pressed.bind(Vector2i(50, 50)))
	blank_80_button.pressed.connect(_on_blank_pressed.bind(Vector2i(80, 80)))

	# --- Load Examples column ---
	example_1_button.pressed.connect(_on_example_pressed.bind(EXAMPLE_PATHS[0]))
	example_2_button.pressed.connect(_on_example_pressed.bind(EXAMPLE_PATHS[1]))
	example_3_button.pressed.connect(_on_example_pressed.bind(EXAMPLE_PATHS[2]))
	example_4_button.pressed.connect(_on_example_pressed.bind(EXAMPLE_PATHS[3]))

	# --- Recent Files column ---
	_populate_recent_files()
	recent_files.item_activated.connect(_on_recent_item_selected)
	recent_files.item_selected.connect(_on_recent_item_selected)
	if is_instance_valid(SettingsManager):
		SettingsManager.recent_files_changed.connect(_populate_recent_files)


func _populate_recent_files() -> void:
	recent_files.clear()
	if not is_instance_valid(SettingsManager):
		return
	for path: String in SettingsManager.recent_files:
		var item_idx := recent_files.add_item(path.get_file())
		recent_files.set_item_tooltip(item_idx, path)
		recent_files.set_item_metadata(item_idx, path)


func _on_recent_item_selected(index: int) -> void:
	var path_val: Variant = recent_files.get_item_metadata(index)
	if path_val is String and not (path_val as String).is_empty():
		Fileman.load_project(path_val as String)
		queue_free()


# Opens the custom-size "New File" dialog and closes the splash.
# If the user cancels NewFilePopup no document will be created (existing behaviour).
func _on_new_file_pressed() -> void:
	PopupManager.open("new_file", NEW_FILE_POPUP)
	queue_free()


# Creates a blank document at the chosen preset size and closes the splash.
func _on_blank_pressed(size: Vector2i) -> void:
	Fileman.new_file(size)
	queue_free()


# Loads one of the bundled example PDC files as an unsaved document and closes
# the splash. Using open_example() instead of pdc_to_gd() ensures the project
# path is left empty, so File → Save prompts "Save As" rather than overwriting
# the bundled asset.
func _on_example_pressed(path: String) -> void:
	Fileman.open_example(path)
	queue_free()
