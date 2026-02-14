extends Node

@export var shop_scene: PackedScene
@export var chest_scene: PackedScene
@export var enemy_scene: PackedScene
@onready var enemy_container = $Enemies
@onready var items_container: Node = $Items
@onready var chest_container: Node = $Chests
@onready var shops_container: Node = $Shops

func _ready():
	spawn_item_givers()
	spawn_enemies()

func spawn_item_givers():
	var item_giver_spawn_points = get_tree().get_nodes_in_group("ItemGiverSpawn")
	
	for marker in item_giver_spawn_points:
		var roll = randf() * 100
		
		if roll < 50:  # 50% chest
			var chest = chest_scene.instantiate()
			chest_container.add_child(chest)
			chest.global_position = marker.global_position
		elif roll < 80:  # 30% shop (not implemented yet)
			var shop = shop_scene.instantiate()
			shops_container.add_child(shop)
			shop.global_position = marker.global_position
		# elif roll < 90:  # 10% statue (not implemented yet)
		#     spawn_statue(marker.global_position)
		# else: 10% nothing

func spawn_enemies():
	var spawn_points = get_tree().get_nodes_in_group("EnemySpawn")
	
	for marker in spawn_points:
		# INFO 50% chance to spawn
		if randf() <= 0.5:
			var new_enemy = enemy_scene.instantiate()
			# INFO Add the slime as a child of the "Enemies" node
			enemy_container.add_child(new_enemy)
			new_enemy.global_position = marker.global_position
			
