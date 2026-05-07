extends Control

const SHOW_ICON = preload("res://assets/icons/show.png")
const HIDE_ICON = preload("res://assets/icons/hide.png")
const VISIBILITY_BUTTON_ID := 1

@onready var tree: Tree = $Tree
var _items_by_command_index: Dictionary = {}
var _syncing_tree_selection := false

func _ready() -> void:
	tree.columns = 2
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_MULTI
	tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
	tree.set_column_custom_minimum_width(1, 24)
	tree.set_column_expand(1, false)
	tree.set_drag_forwarding(
		Callable(self, "_tree_get_drag_data"),
		Callable(self, "_tree_can_drop_data"),
		Callable(self, "_tree_drop_data"),
	)
	tree.multi_selected.connect(_on_tree_multi_selected)
	tree.empty_clicked.connect(_on_tree_empty_clicked)
	tree.button_clicked.connect(_on_tree_button_clicked)

	ProjectData.data_changed.connect(_on_data_changed)
	EditorState.selection_changed.connect(_on_editor_selection_changed)
	_rebuild_tree()


func _on_data_changed(_by_user: bool) -> void:
	_rebuild_tree()


func _rebuild_tree() -> void:
	tree.clear()
	_items_by_command_index.clear()
	var root := tree.create_item()

	var image: DrawCommandImage = ProjectData.get_current_image()
	if image == null:
		return

	var commands: Array = image.commands
	for command_idx in range(commands.size() - 1, -1, -1):
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
		_items_by_command_index[command_idx] = item

	_sync_tree_selection_from_editor_state()

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

	var image: DrawCommandImage = ProjectData.get_current_image()
	if image == null:
		tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
		return
	var command_count := image.commands.size()
	if command_count <= 1:
		tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
		return

	var source_command_idx := int(data["command_index"])
	if source_command_idx < 0 or source_command_idx >= command_count:
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

	var target_command_idx := int(target_command_meta)
	if target_command_idx < 0 or target_command_idx >= command_count:
		tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
		return

	var source_display_idx := _command_index_to_display_index(command_count, source_command_idx)
	var target_display_idx := _command_index_to_display_index(command_count, target_command_idx)

	var drop_section := tree.get_drop_section_at_position(at_position)
	if drop_section == 1:
		target_display_idx += 1

	if target_display_idx > source_display_idx:
		target_display_idx -= 1

	if target_display_idx == source_display_idx:
		tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
		return

	var destination_command_idx := _display_index_to_command_insert_index(command_count, target_display_idx)
	var frame_idx := EditorState.current_frame
	HistoryManager.commit(
		ReorderDrawCommandAction.new(frame_idx, source_command_idx, destination_command_idx)
	)
	tree.drop_mode_flags = Tree.DROP_MODE_DISABLED


func _command_index_to_display_index(command_count: int, command_index: int) -> int:
	return command_count - 1 - command_index


func _display_index_to_command_insert_index(command_count: int, display_index: int) -> int:
	return command_count - 1 - display_index


func _on_tree_multi_selected(_item: TreeItem, _column: int, _selected: bool) -> void:
	if _syncing_tree_selection:
		return
	_apply_editor_selection_from_tree()

func _on_tree_empty_clicked(_position: Vector2, _mouse_button_index: int) -> void:
	if _syncing_tree_selection:
		return
	EditorState.deselect_all()


func _on_editor_selection_changed(_by_user: bool) -> void:
	if not _by_user:
		return
	_sync_tree_selection_from_editor_state()


func _sync_tree_selection_from_editor_state() -> void:
	_syncing_tree_selection = true
	tree.deselect_all()

	var selected_commands := {}
	for command_index in EditorState.selected_command_indices:
		selected_commands[command_index] = true
	for command_index in EditorState.selected_point_indices:
		selected_commands[command_index] = true

	for command_index in selected_commands:
		if _items_by_command_index.has(command_index):
			var item: TreeItem = _items_by_command_index[command_index]
			item.select(0)

	_syncing_tree_selection = false


func _apply_editor_selection_from_tree() -> void:
	var image: DrawCommandImage = ProjectData.get_current_image()
	if image == null:
		return

	var selected_commands: Array[int] = []
	var iter: TreeItem = tree.get_next_selected(null)
	while iter != null:
		var command_index_meta: Variant = iter.get_metadata(0)
		if command_index_meta != null:
			var command_index := int(command_index_meta)
			if command_index >= 0 and command_index < image.commands.size():
				selected_commands.append(command_index)
		iter = tree.get_next_selected(iter)

	EditorState.selected_command_indices = selected_commands
	EditorState.selected_point_indices.clear()
	for command_index in selected_commands:
		var command: DrawCommand = image.commands[command_index]
		var point_indices: Array[int] = []
		for point_idx in range(command.points.size()):
			point_indices.append(point_idx)
		EditorState.selected_point_indices[command_index] = point_indices
	EditorState.selection_changed.emit(false)


func _on_tree_button_clicked(
	item: TreeItem,
	_column: int,
	id: int,
	_mouse_button_index: int,
) -> void:
	if id != VISIBILITY_BUTTON_ID:
		return
	if item == null:
		return

	var image: DrawCommandImage = ProjectData.get_current_image()
	if image == null:
		return

	var command_index_meta: Variant = item.get_metadata(0)
	if command_index_meta == null:
		return

	var command_index := int(command_index_meta)
	if command_index < 0 or command_index >= image.commands.size():
		return

	var command: DrawCommand = image.commands[command_index]
	HistoryManager.commit(
		DrawCommandPropertyAction.new(
			"Toggle Layer Visibility",
			EditorState.current_frame,
			[command_index],
			&"hidden",
			not command.hidden,
		)
	)
