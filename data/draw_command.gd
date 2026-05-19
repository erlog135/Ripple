class_name DrawCommand extends RefCounted

enum Type {INVALID, PATH, CIRCLE, PRECISE_PATH}
var draw_type: Type = Type.INVALID
var hidden: bool
var stroke_color: Color
var stroke_width: int

var fill_color: Color
var path_open: bool

var circle_radius: int

var points: PackedVector2Array


func get_bounding_box() -> Rect2:
	if points.is_empty():
		return Rect2()
	if draw_type == Type.CIRCLE:
		var half := float(circle_radius) + stroke_width * 0.5
		return Rect2(points[0] - Vector2(half, half), Vector2(half, half) * 2.0)
	var min_p := points[0]
	var max_p := points[0]
	for p: Vector2 in points:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var margin := stroke_width * 0.5
	return Rect2(min_p - Vector2(margin, margin), max_p - min_p + Vector2(margin, margin) * 2.0)
