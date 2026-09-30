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


## Determines if the selection in [param frame] targets an active path command suitable
## for pen drawing / rubber band preview (either a single endpoint or two adjacent points).
static func get_pen_rubber_band_context(frame: RefCounted, selected_point_indices: Dictionary, selected_command_indices: Array) -> Dictionary:
	if selected_point_indices.is_empty():
		return {}

	var sel_keys := selected_point_indices.keys()
	if sel_keys.size() != 1:
		return {}

	var cmd_idx: int = int(sel_keys[0])
	if selected_command_indices.size() > 1:
		return {}

	for k in selected_command_indices:
		if int(k) != cmd_idx:
			return {}

	if cmd_idx not in selected_point_indices:
		return {}

	if frame == null or cmd_idx < 0 or cmd_idx >= frame.commands.size():
		return {}

	var cmd: DrawCommand = frame.commands[cmd_idx]
	if cmd.hidden:
		return {}

	if cmd.draw_type != Type.PATH and cmd.draw_type != Type.PRECISE_PATH:
		return {}

	var raw_pts: Array = selected_point_indices[cmd_idx]
	var uniq: Dictionary = {}
	var pts: Array = []
	for x in raw_pts:
		if not (x is int):
			continue
		var xi := int(x)
		if xi >= 0 and xi < cmd.points.size() and not uniq.has(xi):
			uniq[xi] = true
			pts.append(xi)
	pts.sort()

	if pts.is_empty() or pts.size() > 2:
		return {}

	if pts.size() == 2:
		var lo: int = pts[0]
		var hi: int = pts[1]
		var n := cmd.points.size()
		var adjacent := (hi - lo == 1) or (not cmd.path_open and lo == 0 and hi == n - 1)
		if not adjacent:
			return {}
		return {
			&"cmd_idx": cmd_idx,
			&"cmd": cmd,
			&"pts": pts,
		}

	var i: int = int(pts[0])
	var n := cmd.points.size()
	if i == 0 or i == n - 1:
		return {
			&"cmd_idx": cmd_idx,
			&"cmd": cmd,
			&"pts": pts,
		}

	return {}
