extends Control

@onready var texture_rect: TextureRect = $TextureRect
@onready var selector_rect: ReferenceRect = $SelectorRect
@onready var unsaved_indicator: Label = $UnsavedIndicator

const TAB_ITEM_SCENE = preload("uid://fn2u0vl812p")
