extends Control

@onready var tree: Tree = $Tree

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var root = tree.create_item()
	tree.add_child(root)

	var layer1 = tree.create_item(root)
	layer1.set_text(0, "Layer 1")
	var layer2 = tree.create_item(root)
	layer2.set_text(0, "Layer 2")
	var layer3 = tree.create_item(root)
	layer3.set_text(0, "Layer 3")
