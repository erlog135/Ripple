extends ColorRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var accent := DisplayServer.get_accent_color()
	accent.a = 0.1
	color = accent
