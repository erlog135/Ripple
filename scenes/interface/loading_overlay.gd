extends CanvasLayer

@onready var progress_bar: ProgressBar = $ProgressBar

func _ready() -> void:
	hide()
	RenderManager.bulk_raster_started.connect(_on_bulk_raster_started)
	RenderManager.bulk_raster_progress.connect(_on_bulk_raster_progress)
	RenderManager.bulk_raster_finished.connect(_on_bulk_raster_finished)


func _on_bulk_raster_started(total: int) -> void:
	# Single-frame rasters are fast enough to not need a visible overlay.
	if total < 2:
		return
	progress_bar.max_value = total
	progress_bar.value = 0
	show()


func _on_bulk_raster_progress(completed: int, _total: int) -> void:
	progress_bar.value = completed


func _on_bulk_raster_finished() -> void:
	hide()


# Consume all input while visible so the user cannot trigger edits mid-rasterization.
func _input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()
