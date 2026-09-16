extends Area2D

var player: CharacterBody2D
@onready var interact_ui: Node2D = $InteractUI
@onready var machine_sprite: AnimatedSprite2D = $MachineSprite
# Called when the node enters the scene tree for the first time.

var was_used = false

func _ready() -> void:
	machine_sprite.animation_finished.connect(_on_machine_animation_finished)

func _on_machine_animation_finished() -> void:
	if machine_sprite.animation == "use":
		machine_sprite.play("default")

func _input(event: InputEvent) -> void:	
	if player and event.is_action_pressed("pickup") and was_used == false:
		machine_sprite.play("use")
		player.heal(player.MAX_HEALTH * 0.8)
		was_used = true
	elif was_used == true:
		interact_ui.hide_ui()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and was_used == false:
		interact_ui.show_ui()
		player = body

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		interact_ui.hide_ui()
		player = null
