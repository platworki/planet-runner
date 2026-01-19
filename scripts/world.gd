extends Node

@export var chest_scene: PackedScene
@export var enemy_scene: PackedScene
@onready var enemy_container = $Enemies
@onready var items_container: Node = $Items
@onready var chest_container: Node = $Chests

func _ready():
	spawn_chests()
	spawn_enemies()

func spawn_chests():
	var chest_spawn_points = get_tree().get_nodes_in_group("ChestSpawn")
	
	for marker in chest_spawn_points:
		var roll = randf() * 100
		
		if roll < 50:  # 50% chest
			var chest = chest_scene.instantiate()
			chest_container.add_child(chest)
			chest.global_position = marker.global_position + Vector2(0,-16)
		# elif roll < 80:  # 30% shop (not implemented yet)
		#     spawn_shop(marker.global_position)
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
			
