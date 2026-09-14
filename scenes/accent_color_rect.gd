extends ColorRect

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	modulate.a = 0.1
	EditorState.bg_color_changed.connect(func(): color = EditorState.current_bg_color)
