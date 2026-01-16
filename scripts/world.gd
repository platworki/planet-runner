extends Node

@export var enemy_scene: PackedScene
@onready var enemy_container = $Enemies
@onready var items_container: Node = $Items

func _ready():
	spawn_enemies()
	spawn_test_item()

func spawn_enemies():
	var spawn_points = get_tree().get_nodes_in_group("EnemySpawn")
	
	for marker in spawn_points:
		# INFO 50% chance to spawn
		if randf() <= 0.5:
			var new_enemy = enemy_scene.instantiate()
			# INFO Add the slime as a child of the "Enemies" node
			enemy_container.add_child(new_enemy)
			new_enemy.global_position = marker.global_position

func spawn_test_item():
	var item_scene = preload("res://scenes/items/item.tscn")
	var item = item_scene.instantiate()
	# Get item data from database
	item.item_data = GameManager.get_item_from_database("precise_map")
	items_container.add_child(item)
	item.global_position = Vector2(600, -270)  # Adjust position
