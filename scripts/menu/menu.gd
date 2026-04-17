extends Control

@onready var start: TextureButton = $Start
@onready var options: TextureButton = $Options
@onready var exit: TextureButton = $Exit

func _on_play_pressed() -> void:
	start.texture_normal = start.texture_hover
	start.disabled = true
	options.disabled = true
	exit.disabled = true
	SceneTransitions.fade_to_scene_white("res://scenes/world.tscn")
	
func _on_quit_pressed():
	get_tree().quit()
