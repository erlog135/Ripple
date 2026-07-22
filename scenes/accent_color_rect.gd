extends ColorRect

var accent: Color
var time := 0.0
const COLOR_SHIFT_AMP = 0.3
const SHIFT_SPEED = 0.5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	accent = DisplayServer.get_accent_color()
	accent.a = 0.1
	color = accent

#func _process(delta: float) -> void:
	#time += delta*SHIFT_SPEED
	#color.r = accent.r * COLOR_SHIFT_AMP * sin(time)
	#color.g = accent.g * COLOR_SHIFT_AMP * sin(time+(2*PI/3))
	#color.b = accent.b * COLOR_SHIFT_AMP * sin(time+(4*PI/3))
