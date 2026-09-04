extends Control

@onready var activity_label: Label = $Panel/MarginContainer/HBoxContainer/ActivityLabel
@onready var version_label: Label = $Panel/MarginContainer/HBoxContainer/VersionLabel

func _ready() -> void:
	version_label.text = "Ripple 0.0 (%s)" % OS.get_name()
	HistoryManager.history_updated.connect(_on_history_updated)
	ProjectData.tab_list_changed.connect(_on_tab_list_changed)
	_update_current_activity()


func _on_history_updated(action_name: String) -> void:
	activity_label.text = action_name


func _on_tab_list_changed() -> void:
	_update_current_activity()


func _update_current_activity() -> void:
	var doc = ProjectData.get_current_document()
	if doc and doc.undo_redo:
		activity_label.text = doc.undo_redo.get_current_action_name()
	else:
		activity_label.text = ""
