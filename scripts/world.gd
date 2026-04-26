extends Node

@export var shop_scene: PackedScene
@export var chest_scene: PackedScene
@export var slime_scene: PackedScene
@export var heli_scene: PackedScene # Add the Helicopter scene here!
@export var fireE_scene: PackedScene # Add the Helicopter scene here!

@onready var enemy_container = $Enemies
@onready var items_container: Node = $Items
@onready var chest_container: Node = $Chests
@onready var shops_container: Node = $Shops
@onready var camera: Camera2D = $Player/Camera2D
@onready var spawn_timer: Timer = $Spawners/SpawnTimer

const MAX_ENEMIES = 30
const OFFSCREEN_MIN = 50 # Must be AT LEAST 50px outside the camera

func _ready():
	#Engine.time_scale = 0.2
	spawn_item_givers()
	spawn_enemies()

func _on_spawn_timer_timeout() -> void:
	spawn_timer.wait_time = snappedf(randf_range(7.0,14.0),0.1)
	
	if enemy_container.get_child_count() >= MAX_ENEMIES:
		return
	# INFO: 50% chance to spawn every time the timer ticks
	if randf() > 0.5:
		return
	attempt_respawn()

func attempt_respawn():
	# 1. Define your weights (Higher = More Common)
	var enemy_weights = {
		"slime": 60, # 70% chance
		"heli": 20,  # 20% chance
		"fireE": 20   # 10% chance
	}
	# 2. Pick an enemy based on weight
	var spawn_type = get_weighted_random(enemy_weights)
	# 3. Proceed with existing logic
	var valid_spawners = get_valid_spawners(spawn_type)
	
	if valid_spawners.size() > 0:
		var chosen_marker = valid_spawners.pick_random()
		spawn_enemy_at(chosen_marker.global_position, spawn_type)

# Helper function to handle the math for you
func get_weighted_random(weights: Dictionary) -> String:
	var total_weight = 0
	for weight in weights.values():
		total_weight += weight
		
	var roll = randi_range(1, total_weight)
	var current_sum = 0
	
	for type in weights:
		current_sum += weights[type]
		if roll <= current_sum:
			return type
	return "slime" # Fallback

func get_valid_spawners(type: String) -> Array:
	var valid = []
	var screen_center = camera.get_screen_center_position()
	var view_size = get_viewport().get_visible_rect().size / camera.zoom
	
	var half_width = view_size.x / 2
	var half_height = view_size.y / 2
	var group_name = "SlimeSpawn"
	
	# Determine which group to look at
	if type == "heli":
		group_name = "HeliSpawn"
	elif type == "fireE":
		group_name = "FireESpawn"
	
	for marker in get_tree().get_nodes_in_group(group_name):
		var pos = marker.global_position
		var dist_x = abs(pos.x - screen_center.x)
		var dist_y = abs(pos.y - screen_center.y)
		
		var is_offscreen = dist_x > (half_width + OFFSCREEN_MIN) or dist_y > (half_height + OFFSCREEN_MIN)
		
		if is_offscreen:
			valid.append(marker)
		
	return valid

func spawn_enemy_at(pos: Vector2, type: String):
	var enemy = null
	if type == "slime":
		enemy = slime_scene.instantiate()
	elif type == "heli":
		enemy = heli_scene.instantiate()
	else:
		enemy = fireE_scene.instantiate()
		
	enemy.global_position = pos
	enemy_container.add_child(enemy)
	print(type, " spawned at ", pos)

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

func spawn_enemies():
	var all_markers = get_tree().get_nodes_in_group("SlimeSpawn")
	all_markers.append_array(get_tree().get_nodes_in_group("HeliSpawn"))
	all_markers.append_array(get_tree().get_nodes_in_group("FireESpawn"))
	
	all_markers.shuffle() 
	
	for marker in all_markers:
		if enemy_container.get_child_count() >= MAX_ENEMIES:
			break 
		
		# Only 40% of markers should actually spawn something at start
		if randf() > 0.4:
			continue

		var type = "fireE"
		if marker.is_in_group("SlimeSpawn"): type = "slime"
		elif marker.is_in_group("HeliSpawn"): type = "heli"
		
		spawn_enemy_at(marker.global_position, type)
