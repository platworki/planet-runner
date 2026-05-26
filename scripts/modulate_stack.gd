extends Node

var layers := {}

func set_layer(key: String, color: Color) -> void:
	layers[key] = color
	_apply()

func remove_layer(key: String) -> void:
	layers.erase(key)
	_apply()

func _apply() -> void:
	var result := Color.WHITE
	for c in layers.values():
		result *= c
	get_parent().modulate = result
