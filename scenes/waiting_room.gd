extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var torso_animation: AnimatedSprite2D = $Player/Position/Torso
@onready var legs_animation: AnimatedSprite2D = $Player/Position/Legs
@onready var pinkdoor: AnimatedSprite2D = $DoorIn
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.input_enabled = true
	torso_animation.play("Idle")
	legs_animation.play("Idle")
	await get_tree().create_timer(2.0).timeout
	pinkdoor.play("default")
	
