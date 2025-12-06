extends Node

@export var enemy_scene: PackedScene
@onready var enemy_container = $Enemies

func _ready():
	spawn_enemies()

func spawn_enemies():
	var spawn_points = get_tree().get_nodes_in_group("EnemySpawn")
	
	for marker in spawn_points:
		# INFO 50% chance to spawn
		if randf() <= 0.5:
			var new_enemy = enemy_scene.instantiate()	
			# INFO Add the slime as a child of the "Enemies" node
			enemy_container.add_child(new_enemy)
			new_enemy.global_position = marker.global_position
