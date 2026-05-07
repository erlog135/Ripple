extends Control

const SHOW_ICON = preload("res://assets/icons/show.png")
const HIDE_ICON = preload("res://assets/icons/hide.png")
const VISIBILITY_BUTTON_ID := 1

@onready var tree: Tree = $Tree
var _display_command_indices: Array[int] = []

func _ready() -> void:
	tree.columns = 2
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
	tree.set_column_custom_minimum_width(1, 24)
	tree.set_column_expand(1, false)
	tree.set_drag_forwarding(
		Callable(self, "_tree_get_drag_data"),
		Callable(self, "_tree_can_drop_data"),
		Callable(self, "_tree_drop_data"),
	)
	tree.button_clicked.connect(_on_tree_button_clicked)

	ProjectData.data_changed.connect(_on_data_changed)
	_rebuild_tree()


func _on_data_changed(_by_user: bool) -> void:
	_rebuild_tree()


func _rebuild_tree() -> void:
	tree.clear()
	var root := tree.create_item()

	var image: DrawCommandImage = ProjectData.get_current_image()
	if image == null:
		_display_command_indices.clear()
		return

	var commands: Array = image.commands
	_sync_display_indices(commands.size())

	for command_idx in _display_command_indices:
		var cmd: DrawCommand = commands[command_idx]
		var item := tree.create_item(root)
		item.set_text(0, _layer_name_for_command(cmd))
		item.set_metadata(0, command_idx)
		item.add_button(
			1,
			SHOW_ICON if not cmd.hidden else HIDE_ICON,
			VISIBILITY_BUTTON_ID,
			false,
			"Visibility",
		)


func _sync_display_indices(command_count: int) -> void:
	if _display_command_indices.size() != command_count:
		_display_command_indices = _make_default_display_indices(command_count)
		return

	var expected := _make_default_display_indices(command_count)
	var seen := {}
	for idx in _display_command_indices:
		if not (idx is int):
			_display_command_indices = expected
			return
		if idx < 0 or idx >= command_count:
			_display_command_indices = expected
			return
		if seen.has(idx):
			_display_command_indices = expected
			return
		seen[idx] = true

	if seen.size() != command_count:
		_display_command_indices = expected


func _make_default_display_indices(command_count: int) -> Array[int]:
	var indices: Array[int] = []
	for idx in range(command_count - 1, -1, -1):
		indices.append(idx)
	return indices


func _layer_name_for_command(cmd: DrawCommand) -> String:
	var openness := "open" if cmd.path_open else "closed"
	if cmd.draw_type == DrawCommand.Type.CIRCLE:
		return "r %d %s circle" % [cmd.circle_radius, openness]
	return "%d pt %s command" % [cmd.points.size(), openness]


func _tree_get_drag_data(at_position: Vector2) -> Variant:
	var item := tree.get_item_at_position(at_position)
	if item == null:
		return null

	var command_idx: Variant = item.get_metadata(0)
	if command_idx == null:
		return null

	var preview := Label.new()
	preview.text = item.get_text(0)
	tree.set_drag_preview(preview)
	return {"command_index": int(command_idx)}


func _tree_can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data == null or not (data is Dictionary) or not data.has("command_index"):
		tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
		return false

	tree.drop_mode_flags = Tree.DROP_MODE_INBETWEEN
	var drop_item := tree.get_item_at_position(at_position)
	var drop_section := tree.get_drop_section_at_position(at_position)
	var can_drop := drop_item != null and (drop_section == -1 or drop_section == 1)
	if not can_drop:
		tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
	return can_drop


func _tree_drop_data(at_position: Vector2, data: Variant) -> void:
	if data == null or not (data is Dictionary):
		tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
		return
	if not data.has("command_index"):
		tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
		return

	var source_command_idx := int(data["command_index"])
	var source_display_idx := _display_command_indices.find(source_command_idx)
	if source_display_idx == -1:
		tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
		return

	var drop_item := tree.get_item_at_position(at_position)
	if drop_item == null:
		tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
		return

	var target_command_meta: Variant = drop_item.get_metadata(0)
	if target_command_meta == null:
		tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
		return

	var target_display_idx := _display_command_indices.find(int(target_command_meta))
	if target_display_idx == -1:
		tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
		return

	var drop_section := tree.get_drop_section_at_position(at_position)
	if drop_section == 1:
		target_display_idx += 1

	if target_display_idx > source_display_idx:
		target_display_idx -= 1

	if target_display_idx == source_display_idx:
		tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
		return

	_display_command_indices.remove_at(source_display_idx)
	_display_command_indices.insert(target_display_idx, source_command_idx)
	tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
	_rebuild_tree()


func _on_tree_button_clicked(
	_item: TreeItem,
	_column: int,
	_id: int,
	_mouse_button_index: int,
) -> void:
	# Visibility controls are display-only for now.
	pass
