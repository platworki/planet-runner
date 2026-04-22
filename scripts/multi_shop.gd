extends Area2D

var player_in_range = false
var is_opened = false
var displayed_items = []
var selected_item = null

@onready var curtains: AnimatedSprite2D = $Curtains
@onready var item_spawn_point: Marker2D = $ItemSpawnPoint
@onready var items_container: Node = $/root/World/Items
@onready var item_spots = $ItemSpots.get_children()

func _ready() -> void:
	setup_display_items()
	
func _process(_delta):
	if player_in_range and not is_opened:
		update_item_selection()
		
		if Input.is_action_just_pressed("pickup"):
			try_purchase()
	
func _on_body_entered(body: Node2D):
	if body.name == "Player":
		player_in_range = true
	
func _on_body_exited(body: Node2D):
	if body.name == "Player":
		player_in_range = false
	
func setup_display_items():
	var item_scene = preload("res://scenes/items/item.tscn")
	
	for spot in item_spots:
		var item = item_scene.instantiate()
		
		var item_data = GameManager.get_random_item_from_database()
		item.item_data = item_data
		item.is_display_only = true
		item.global_position = spot.global_position
		
		# ❗ IMPORTANT: disable physics + pickup
		item.set_physics_process(false)
		item.can_pickup = false
		item.scale = Vector2(0.4,0.4)
		items_container.add_child(item)
		displayed_items.append(item)
	
func update_item_selection():
	if displayed_items.is_empty():
		return
	
	var closest = null
	var closest_dist = INF
	
	for item in displayed_items:
		var dist = item.global_position.distance_to(get_tree().get_nodes_in_group("Player")[0].global_position)
		
		if dist < closest_dist:
			closest_dist = dist
			closest = item
	
	# Update highlight visuals
	for item in displayed_items:
		item.set_highlight(item == closest)
	
	selected_item = closest
	
func try_purchase():
	if selected_item == null:
		return
	var cost = 5
	# Wait for animation to play long enough
	if GameManager.can_spend_currency(cost):
		buy_item()
	else:
		print("Not enough money")

func buy_item():
	is_opened = true
	var item = selected_item
	item.z_index = 8
	# REMOVE it from the list first
	displayed_items.erase(item)
	
	# Turn it into a real item
	item.is_display_only = false
	item.set_physics_process(true)
	item.can_pickup = false
	
	# Pop effect
	item.velocity = Vector2(randf_range(-30, 30), -120)
	item.scale = Vector2(0.65, 0.65)
	
	# Optional: slight horizontal randomness feels better
	item.velocity.x = randf_range(-50, 50)
	
	# Now delete ONLY the other items
	for other_item in displayed_items:
		other_item.queue_free()
	
	displayed_items.clear()
	
	curtains.play("closing")
	print("Item bought")
