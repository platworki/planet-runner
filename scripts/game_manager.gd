extends Node

# Inventory storage
var inventory = []

# Player stat bonuses (applied from items)
var player_stats = {
	"speed_bonus": 0, # %
	"damage_bonus": 0, # %
	"health_bonus": 0, # INT
	"crit_chance": 0 # %
}

func add_item(item_data: Dictionary):
	inventory.append(item_data)
	apply_item_effect(item_data)
	print("Picked up: ", item_data.name)
	print("Inventory size: ", inventory.size())

func apply_item_effect(item: Dictionary):
	match item.effect_type:
		"speed":
			player_stats.speed_bonus += item.value
		"damage":
			player_stats.damage_bonus += item.value
		"health":
			player_stats.health_bonus += item.value
		"crit_chance":
			player_stats.crit_chance += item.value

func get_item_from_database(item_name: String) -> Dictionary:
	if ITEM_DATABASE.has(item_name):
		return ITEM_DATABASE[item_name].duplicate()
	else:
		push_error("Item not found: " + item_name)
		return {}

# Item database - all possible items
const ITEM_DATABASE = {
	"speed_boots": {
		"name": "Speedy Boot",
		"effect_type": "speed",
		"value": 15,  # Percentage
		"rarity": "common",
		"sprite_default": "res://assets/sprites/speed_boot_sprite.png",
		"sprite_highlight": "res://assets/sprites/speed_boot-highlight.png",
		"description": "+15% movement speed"
	},
	"precise_map": {
		"name": "Precise Map",
		"effect_type": "crit_chance",
		"value": 15,
		"rarity": "rare",
		"sprite_default": "res://assets/sprites/crit_map_sprite.png",
		"sprite_highlight": "res://assets/sprites/crit_map_highlight.png"
	}
	# Add more...
}
