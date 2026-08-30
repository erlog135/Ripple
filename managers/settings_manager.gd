extends Node

## SettingsManager (Autoload)
## Manages persistent application configuration and history (editor scale, recent files, etc.)
## stored in "user://settings.cfg" via Godot's ConfigFile.

const SETTINGS_PATH: String = "user://settings.cfg"

signal settings_changed
signal editor_scale_changed(scale: float)
signal recent_files_changed

## UI / Editor content scale factor (clamped between 0.5 and 3.0).
var editor_scale: float = 1.0:
	set(value):
		var clamped := clampf(value, 0.5, 3.0)
		if is_equal_approx(editor_scale, clamped):
			return
		editor_scale = clamped
		_apply_editor_scale()
		save_settings()
		editor_scale_changed.emit(editor_scale)

## List of absolute file paths to recently saved or opened files (max 10).
var recent_files: Array[String] = []


func _ready() -> void:
	load_settings()


## Loads settings from disk. If the settings file does not exist, saves default settings.
func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)

	if err == OK:
		editor_scale = config.get_value("display", "editor_scale", config.get_value("display", "ui_scale", 1.0))
		var raw_recents = config.get_value("history", "recent_files", [])
		recent_files.clear()
		if raw_recents is Array:
			for item in raw_recents:
				if item is String and not (item as String).is_empty():
					recent_files.append(item as String)
		_apply_editor_scale()
	else:
		save_settings()


## Saves the current settings to disk and emits settings_changed.
func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value("display", "editor_scale", editor_scale)
	config.set_value("history", "recent_files", recent_files)

	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_error("SettingsManager: Failed to save settings to '%s' (error %d)" % [SETTINGS_PATH, err])

	settings_changed.emit()


## Sets the editor scale, clamps it within a safe range [0.5, 3.0], applies it to the root window,
## and persists the new setting.
func set_editor_scale(scale: float) -> void:
	editor_scale = scale


## Applies the current editor scale to the root window's content scale factor.
func _apply_editor_scale() -> void:
	if get_tree() != null and get_tree().root != null:
		get_tree().root.content_scale_factor = editor_scale


## Adds a file path to the recent files list (LRU order, max 10 entries) and saves immediately.
func add_recent_file(path: String) -> void:
	if path.is_empty() or path.begins_with("res://") or path.begins_with("web://"):
		return

	var existing_index := recent_files.find(path)
	if existing_index != -1:
		recent_files.remove_at(existing_index)

	recent_files.push_front(path)

	if recent_files.size() > 10:
		recent_files.pop_back()

	save_settings()
	recent_files_changed.emit()


## Removes a file path from the recent files list and saves immediately.
func remove_recent_file(path: String) -> void:
	var existing_index := recent_files.find(path)
	if existing_index != -1:
		recent_files.remove_at(existing_index)
		save_settings()
		recent_files_changed.emit()


## Clears all recent files and saves immediately.
func clear_recent_files() -> void:
	recent_files.clear()
	save_settings()
	recent_files_changed.emit()
