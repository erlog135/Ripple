extends Control

const TAB_ITEM_SCENE := preload("uid://fn2u0vl812p")

@onready var hbox: HBoxContainer = $ScrollContainer/HBoxContainer


func _ready() -> void:
	ProjectData.tab_list_changed.connect(_rebuild_tabs)
	ProjectData.data_changed.connect(_on_data_changed)
	ProjectData.dirty_state_changed.connect(_update_dirty_states)
	RenderManager.preview_updated.connect(_on_preview_updated)
	RenderManager.bulk_raster_finished.connect(_refresh_all_thumbnails)
	_rebuild_tabs()


# ---------------------------------------------------------------------------
# Full rebuild — called when the tab list structure changes (add / close / replace)
# ---------------------------------------------------------------------------

func _rebuild_tabs() -> void:
	# Remove all existing tab widgets.
	for child in hbox.get_children():
		hbox.remove_child(child)
		child.queue_free()

	var docs := ProjectData.open_documents
	for i in docs.size():
		var doc := docs[i]
		var item: Control = TAB_ITEM_SCENE.instantiate()
		hbox.add_child(item)
		var is_active := (i == ProjectData.active_document_index)
		item.setup(i, doc.sequence, is_active, doc.is_dirty)
		item.tab_clicked.connect(_on_tab_clicked)
		item.tab_closed.connect(_on_tab_closed)


# ---------------------------------------------------------------------------
# Lightweight update — called when document content changes (no structural change)
# ---------------------------------------------------------------------------

func _on_data_changed(_by_user: bool, _affected_frame: int) -> void:
	_sync_active_states()
	_refresh_active_thumbnail()
	_update_dirty_states()


func _update_dirty_states() -> void:
	var docs := ProjectData.open_documents
	var children := hbox.get_children()
	for i in mini(docs.size(), children.size()):
		var child = children[i]
		if child.has_method("set_unsaved"):
			child.set_unsaved(docs[i].is_dirty)


func _on_preview_updated() -> void:
	# RenderManager finished rasterizing — refresh thumbnails for all tabs
	# so off-screen tabs that were just rasterized get their picture.
	_refresh_all_thumbnails()


func _sync_active_states() -> void:
	var active_idx := ProjectData.active_sequence_index
	var i := 0
	for child in hbox.get_children():
		if child.has_method("set_active"):
			child.set_active(i == active_idx)
		i += 1


## Refreshes the thumbnail of only the currently active tab.
## Always shows frame 0 so the tab thumbnail is stable regardless of
## which animation frame the timeline is parked on.
## Uses get_frame_texture() (rasterizes on demand) to stay in sync with
## the timeline's frame thumbnails, rather than the cache-only get_image_texture().
func _refresh_active_thumbnail() -> void:
	var active_idx := ProjectData.active_sequence_index
	var seq := ProjectData.get_current_sequence()
	if seq == null or seq.frames.is_empty():
		return
	if active_idx < 0 or active_idx >= hbox.get_child_count():
		return
	var item := hbox.get_child(active_idx)
	if item.has_method("update_thumbnail"):
		item.update_thumbnail(RenderManager.get_frame_texture(0))


## Refreshes thumbnails for all tabs from the render cache.
## Called after bulk rasterization completes so all tabs get their pictures.
func _refresh_all_thumbnails() -> void:
	var seqs := ProjectData.open_sequences
	var i := 0
	for child in hbox.get_children():
		if i < seqs.size() and child.has_method("update_thumbnail"):
			var seq: DrawCommandSequence = seqs[i]
			if seq != null and not seq.frames.is_empty():
				child.update_thumbnail(RenderManager.get_image_texture(seq.frames[0]))
		i += 1


# ---------------------------------------------------------------------------
# Event handlers from TabItem signals
# ---------------------------------------------------------------------------

func _on_tab_clicked(index: int) -> void:
	ProjectData.set_active_sequence(index)


## Close button pressed: free the per-tab history first, then remove the tab.
## HistoryManager.remove_tab() is safe to call here because tab_removed is
## emitted inside ProjectData.close_sequence() which also handles the same cleanup
## via signal — calling remove_tab() first means the signal handler is a no-op.
func _on_tab_closed(index: int) -> void:
	if ProjectData.open_documents.size() <= 1:
		return  # Cannot close the last tab.
	
	var doc = ProjectData.open_documents[index]
	if doc.is_dirty:
		var confirm_dialog := ConfirmationDialog.new()
		confirm_dialog.dialog_text = "Close tab without saving? Your unsaved work will be lost!"
		confirm_dialog.confirmed.connect(func():
			_force_close_tab(index)
			confirm_dialog.queue_free()
		)
		confirm_dialog.canceled.connect(func():
			confirm_dialog.queue_free()
		)
		get_tree().root.add_child(confirm_dialog)
		confirm_dialog.popup_centered()
	else:
		_force_close_tab(index)


func _force_close_tab(index: int) -> void:
	# Disconnect signals from the item about to be removed to avoid stale calls.
	if index < hbox.get_child_count():
		var item := hbox.get_child(index)
		if item.has_signal("tab_clicked"):
			item.tab_clicked.disconnect(_on_tab_clicked)
		if item.has_signal("tab_closed"):
			item.tab_closed.disconnect(_on_tab_closed)
	# History first (remove_tab is idempotent with tab_removed signal).
	HistoryManager.remove_tab(index)
	# Then close in ProjectData (emits tab_removed + tab_list_changed + data_changed).
	ProjectData.close_sequence(index)
