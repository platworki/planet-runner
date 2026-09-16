extends Area2D

var player: CharacterBody2D
@onready var interact_ui: Node2D = $InteractUI

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _input(event: InputEvent) -> void:	
	if player and event.is_action_pressed("pickup"):
		set_process_input(false)
		set_physics_process(false)
		player.input_enabled = false
		SceneTransitions.fade_to_scene_black("res://scenes/menu.tscn")
		GameManager.reset_game()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		interact_ui.show_ui()
		player = body

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		interact_ui.hide_ui()
		player = null
