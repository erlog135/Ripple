class_name DrawCommand extends RefCounted

enum type {INVALID, PATH, CIRCLE, PRECISE_PATH}
var draw_type: int = type.INVALID
var hidden: bool
var stroke_color: Color
var stroke_width: int

var fill_color: Color
var path_open: bool

var circle_radius: int

var points: PackedVector2Array
