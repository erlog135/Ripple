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


## Returns an independent deep copy. DrawCommand extends RefCounted (not Resource),
## so it has no built-in duplicate(); the clipboard relies on this to avoid handing
## out shared references that would mutate when the original is edited.
func clone() -> DrawCommand:
	var c := DrawCommand.new()
	c.draw_type = draw_type
	c.hidden = hidden
	c.stroke_color = stroke_color
	c.stroke_width = stroke_width
	c.fill_color = fill_color
	c.path_open = path_open
	c.circle_radius = circle_radius
	c.points = points.duplicate()
	return c


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
