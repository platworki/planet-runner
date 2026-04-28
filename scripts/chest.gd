extends Area2D

var player_in_range = false
var is_opened = false
const CHEST_COST = 5

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var item_spawn_point: Marker2D = $ItemSpawnPoint
@onready var items_container: Node = $/root/World/Items
@onready var opening_sfx: AudioStreamPlayer = $Opening
@onready var interact_ui: Node2D = $InteractUI

func _on_body_entered(body: Node2D):
	if body.name == "Player":
		interact_ui.show_ui(CHEST_COST)
		player_in_range = true

func _on_body_exited(body: Node2D):
	if body.name == "Player":
		interact_ui.hide_ui()
		player_in_range = false

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("pickup") and not is_opened:
		open_chest()

func open_chest():
	if GameManager.currency >= CHEST_COST:
		GameManager.currency -= CHEST_COST
		is_opened = true
		interact_ui.lock_and_hide()
		animated_sprite.play("opening")
		opening_sfx.pitch_scale = randf_range(0.6,0.9)
		opening_sfx.play()
		# Wait for animation to play long enough
		await get_tree().create_timer(0.7).timeout
		# Spawn item
		spawn_item()
	else:
		interact_ui.flash_ui_red()
		print("Not enough currency!")

func spawn_item():
	# Load item scene
	var item_scene = preload("res://scenes/items/item.tscn")
	var item = item_scene.instantiate()
	
	# Set item data (speed boots for now)
	item.item_data = GameManager.get_random_item_from_database()
	item.global_position = item_spawn_point.global_position
	# Add to world (not as child of chest)
	items_container.add_child(item)
	
	# Give upward velocity
	item.velocity = Vector2(randf_range(-60, 60), -220)
