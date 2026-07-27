extends Window

## Controller for the Welcome / Splash screen shown on first launch.
##
## MVC separation: this node is purely View + Controller. It collects the
## user's choice and forwards it to the appropriate manager:
##   - Fileman.new_file()      → blank document of a preset size
##   - Fileman.pdc_to_gd()    → load an example PDC from res://test/pdc/
##   - PopupManager.open()    → open the custom-size "New File" dialog
##
## No ProjectData, EditorState, or DrawCommandSequence access here.

const NEW_FILE_POPUP := "res://scenes/interface/popups/NewFilePopup.tscn"

# Example PDC files bundled with the project.
# Update these paths when the final examples are chosen.
const EXAMPLE_PATHS := [
	"res://test/pdc/confirm_sequence.pdc",
	"res://test/pdc/mute_sequence.pdc",
	"res://test/pdc/Fin_50px.pdc",
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
