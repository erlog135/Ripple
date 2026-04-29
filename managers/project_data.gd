extends Node

signal data_changed(by_user: bool)

var current_sequence: DrawCommandSequence

func set_current_sequence(sequence: DrawCommandSequence):
	current_sequence = sequence
	data_changed.emit(true)
