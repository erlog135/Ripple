extends Control


func _ready() -> void:
	# Show the welcome splash the very first time the editor opens,
	# before any project has been loaded. PopupManager prevents duplicates
	# if something else somehow triggers this path a second time.
	if ProjectData.open_documents.is_empty():
		PopupManager.open.call_deferred("splash", "res://scenes/interface/popups/SplashPopup.tscn")
