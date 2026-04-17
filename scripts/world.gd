extends Node

@export var shop_scene: PackedScene
@export var chest_scene: PackedScene
@export var slime_scene: PackedScene
@export var heli_scene: PackedScene # Add the Helicopter scene here!

@onready var enemy_container = $Enemies
@onready var items_container: Node = $Items
@onready var chest_container: Node = $Chests
@onready var shops_container: Node = $Shops
@onready var camera: Camera2D = $Player/Camera2D
@onready var spawn_timer: Timer = $Spawners/SpawnTimer

const MAX_ENEMIES = 12
const OFFSCREEN_MIN = 50 # Must be AT LEAST 50px outside the camera

func _ready():
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
	# Decide WHAT to spawn first (75% Slime, 25% Heli)
	var spawn_type = "slime"
	if randf() > 0.75:
		spawn_type = "heli"
	
	var valid_spawners = get_valid_spawners(spawn_type)
	
	if valid_spawners.size() > 0:
		var chosen_marker = valid_spawners.pick_random()
		spawn_enemy_at(chosen_marker.global_position, spawn_type)

func get_valid_spawners(type: String) -> Array:
	var valid = []
	var screen_center = camera.get_screen_center_position()
	var view_size = get_viewport().get_visible_rect().size / camera.zoom
	
	var half_width = view_size.x / 2
	var half_height = view_size.y / 2
	
	# Determine which group to look at
	var group_name = "SlimeSpawn" if type == "slime" else "HeliSpawn"
	
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
	else:
		enemy = heli_scene.instantiate()
		
	enemy.global_position = pos
	enemy_container.add_child(enemy)
	print(type, " spawned at ", pos)

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
		else: # 10% nothing
			pass

func spawn_enemies():
	var all_markers = get_tree().get_nodes_in_group("SlimeSpawn")
	all_markers.append_array(get_tree().get_nodes_in_group("HeliSpawn"))
	
	all_markers.shuffle() # Randomize the order of markers
	
	for marker in all_markers:
		if enemy_container.get_child_count() >= MAX_ENEMIES:
			break # Use break to stop the loop
			
		# Check which group the marker belongs to
		var type = "slime" if marker.is_in_group("SlimeSpawn") else "heli"
		
		# Set your spawn chances
		var chance = 0.5 if type == "slime" else 0.4
		
		if randf() <= chance:
			spawn_enemy_at(marker.global_position, type)
