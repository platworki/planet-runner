extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var torso_animation: AnimatedSprite2D = $Player/Position/Torso
@onready var legs_animation: AnimatedSprite2D = $Player/Position/Legs
@onready var pinkdoor: AnimatedSprite2D = $DoorIn
@export var shop_scene: PackedScene
@export var chest_scene: PackedScene
@onready var items_container: Node = $Items
@onready var chest_container: Node = $Chests
@onready var shops_container: Node = $Shops
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spawn_item_givers()
	player.input_enabled = true
	torso_animation.play("Idle")
	legs_animation.play("Idle")
	await get_tree().create_timer(2.0).timeout
	pinkdoor.play("default")
	
func spawn_item_givers():
	var item_giver_spawn_points = get_tree().get_nodes_in_group("ItemGiverSpawn")
	
	for marker in item_giver_spawn_points:
		var roll = randf() * 100
		
		if roll < 50:  # 50% chest
			var chest = chest_scene.instantiate()
			chest.global_position = marker.global_position
			chest_container.add_child(chest)
		elif roll < 80:  # 30% shop (not implemented yet)
			var shop = shop_scene.instantiate()
			shop.global_position = marker.global_position
			shops_container.add_child(shop)
		else: # 10% nothing
			pass
