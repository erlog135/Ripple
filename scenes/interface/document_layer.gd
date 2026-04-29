extends Control

@export var zoom_speed := 0.1
@export var min_zoom := 0.2
@export var max_zoom := 50.0

@onready var camera: Camera2D = $Node2D/Camera2D

func _ready() -> void:
	pass


func set_camera_offset(offset: Vector2) -> void:
	camera.position += offset


func zoom_in(screen_pos: Vector2) -> void:
	_zoom_towards(screen_pos, 1.0 + zoom_speed)


func zoom_out(screen_pos: Vector2) -> void:
	_zoom_towards(screen_pos, 1.0 - zoom_speed)


func _zoom_towards(screen_pos: Vector2, zoom_factor: float) -> void:
	var previous_zoom := camera.zoom
	var new_zoom_val = clamp(camera.zoom.x * zoom_factor, min_zoom, max_zoom)
	var new_zoom := Vector2(new_zoom_val, new_zoom_val)

	# Offset from viewport center to mouse in screen space.
	# delta_C = screen_offset * (1/Z_old - 1/Z_new) keeps the world point
	# under the cursor fixed as zoom changes.
	var screen_offset := screen_pos - get_viewport_rect().size / 2.0
	camera.position += screen_offset * (Vector2.ONE / previous_zoom - Vector2.ONE / new_zoom)
	camera.zoom = new_zoom
