extends Node

signal stats_changed
# Inventory storage
var inventory = []
var currency = 100
var player_node = null
var combo_board_buff_stacks = 0

# Player stat bonuses (applied from items)
var player_stats = {
	"speed_bonus": 0, # %
	"damage_bonus": 0, # %
	"health_bonus": 0, # INT
	"crit_chance": 0, # %
	"damage_reduction": 0.0, # NEW: 0.0 to 1.0 (0% to 100%)
	"insta_kill_chance": 0.0, # %
	"attack_speed_multiplier": 1.0, # NEW: 1.0 is default
	"shield_active": false,
	"shield_cooldown_max": 20.0
}

const MAX_STACKS = {
	"speed_boots": 3,
	"precise_map": 3,
	"thick_root": 2,
	"combo_board": 3,
	"green_buge": 2,
	"protective_plushie": 5,
	"reality_eraser": 4,
	"swift_scarf": 4,
	"crystal_buckler": 5
}

# 2. Track current stacks
var item_stacks = {
	"speed_boots": 0,
	"precise_map": 0,
	"thick_root": 0,
	"combo_board": 0, # NEW
	"green_buge": 0,
	"protective_plushie": 0,
	"reality_eraser": 0, # NEW
	"swift_scarf": 0,
	"crystal_buckler": 0
}

var combo_board_timer = 0.0
var buckler_timer = 0.0

func _process(delta: float) -> void:
	if player_node:
		if player_stats.shield_active:
			player_node.torso_animation.modulate = Color(1.0, 0.661, 0.999, 1.0) 
		else:
			player_node.torso_animation.modulate = Color.WHITE
	
	if combo_board_timer > 0:
		combo_board_timer -= delta
		if combo_board_timer <= 0:
			combo_board_buff_stacks = 0 # Buff wears off
			print("Combo Board buff expired")
		
	if item_stacks.crystal_buckler > 0 and not player_stats.shield_active:
		buckler_timer -= delta
		if buckler_timer <= 0:
			player_node.shield_charge_sfx.play()
			player_stats.shield_active = true
			print("Shield Charged!")

func is_item_maxed(item_id: String) -> bool:
	if MAX_STACKS.has(item_id):
		return item_stacks[item_id] >= MAX_STACKS[item_id]
	return false

func add_currency(amount: int) -> void:
	currency += amount
	print("Currency: ", currency)

func can_spend_currency(amount: int) -> bool:
	if currency >= amount:
		currency -= amount
		return true
	return false  # Can't afford

func add_item(item_id: String):
	if is_item_maxed(item_id):
		print("Item ", item_id, " is already maxed!")
		return

	var item_data = get_item_from_database(item_id)
	if item_data.is_empty(): 
		return # Prevents the game from crashing if an error happens
		
	inventory.append(item_data)
	apply_item_effect(item_id)
	
	stats_changed.emit()
	
	# FIXED: Dictionary syntax
	print("Picked up: ", item_data["name"]) 
	print("Inventory size: ", inventory.size())
	
	var ui = get_tree().get_nodes_in_group("UI")
	if not ui.is_empty():
		ui[0].update_item_display()

func apply_item_effect(item_id: String):
	if item_stacks.has(item_id):
		item_stacks[item_id] += 1
	match item_id:
		"speed_boots":
			var total_raw = item_stacks.speed_boots * 0.15
			player_stats.speed_bonus = (total_raw / (1.0 + total_raw)) * 100
		"precise_map":
			# Simple stacking for crit, since it has a low max stack (3)
			player_stats.crit_chance = item_stacks.precise_map * 10 # 10, 20, 30%
		"thick_root":
			# We don't change stats, we just tracked the stack increase above
			pass
		"combo_board":
			pass
		"green_buge":
			pass
		"protective_plushie":
			# 5% base + 3% per extra stack
			player_stats.damage_reduction = 0.05 + ((item_stacks.protective_plushie - 1) * 0.03)
		"reality_eraser":
			# 3% base + 1% per extra stack
			player_stats.insta_kill_chance = 3.0 + ((item_stacks.reality_eraser - 1) * 1.0)
		"swift_scarf":
			# 5% base + 5% per extra stack
			# Stack 1: 1.05 | Stack 5: 1.25 (25% faster)
			player_stats.attack_speed_multiplier = 1.0 + (item_stacks.swift_scarf * 0.1)
		"crystal_buckler":
			# 20s -> 18s -> 16.2s etc.
			player_stats.shield_cooldown_max = 20.0 * pow(0.9, item_stacks.crystal_buckler - 1)
			# If they just bought it, start the timer
			if not player_stats.shield_active and buckler_timer <= 0:
				buckler_timer = player_stats.shield_cooldown_max

func get_item_from_database(item_name: String) -> Dictionary:
	if ITEM_DATABASE.has(item_name):
		var data = ITEM_DATABASE[item_name].duplicate()
		data["id"] = item_name # NEW: Inject the ID so the item remembers it
		return data
	else:
		push_error("Item not found: " + item_name)
		return {}

func get_random_item_from_database() -> Dictionary:
	var roll = randf() * 100
	var target_rarity = ""
	
	if roll < 60:  target_rarity = "common"
	elif roll < 90:  target_rarity = "rare"
	else:  target_rarity = "super_rare"
	
	var items_of_rarity = []
	for item_name in ITEM_DATABASE:
		if ITEM_DATABASE[item_name].rarity == target_rarity:
			items_of_rarity.append(item_name)
	
	if items_of_rarity.is_empty():
		push_warning("No items found for rarity: " + target_rarity)
		for item_id in ITEM_DATABASE:
			if ITEM_DATABASE[item_id].rarity == "common":
				items_of_rarity.append(item_id)
	
	var random_item_name = items_of_rarity[randi() % items_of_rarity.size()]
	
	var data = ITEM_DATABASE[random_item_name].duplicate()
	data["id"] = random_item_name # NEW: Inject the true ID!
	return data
	
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
		"sprite_highlight": "res://assets/sprites/crit_map_highlight.png",
		"description": "+15% crit percentage"
	},
	"thick_root": {
		"name": "Thick Root",
		"effect_type": "thick_root",
		"value": 1, # We use this to track stacks
		"rarity": "super_rare",
		"sprite_default": "res://assets/sprites/Items/thick_root/big_root.png",
		"sprite_highlight": "res://assets/sprites/Items/thick_root/big_root_highlight.png",
		"description": "Heal on kill"
	},
	"combo_board": {
		"name": "Combo Board",
		"rarity": "rare",
		"sprite_default": "res://assets/sprites/Items/combo_board/suspicious_scoreboard.png",
		"sprite_highlight": "res://assets/sprites/Items/combo_board/suspicious_scoreboard_highlight.png",
		"description": "2nd hit grants damage buff"
	},
	"green_buge": {
		"name": "Green Buge",
		"rarity": "rare",
		"sprite_default": "res://assets/sprites/Items/green_buge/strong_beetle.png",
		"sprite_highlight": "res://assets/sprites/Items/green_buge/strong_beetle_highlight.png",
		"description": "Stronger 2nd combo hit"
	},
	"protective_plushie": {
		"name": "Protective Plushie",
		"rarity": "common",
		"sprite_default": "res://assets/sprites/Items/protective_plushie/shork_plushie.png",
		"sprite_highlight": "res://assets/sprites/Items/protective_plushie/shork_plushie_highlight.png",
		"description": "Reduces incoming damage"
	},
	"reality_eraser": {
		"name": "Reality Eraser",
		"rarity": "rare",
		"sprite_default": "res://assets/sprites/Items/reality_eraser/eraser.png",
		"sprite_highlight": "res://assets/sprites/Items/reality_eraser/eraser_highlight.png",
		"description": "Small chance to insta-kill non-bosses"
	},
	"swift_scarf": {
		"name": "Swift Scarf",
		"rarity": "rare",
		"sprite_default": "res://assets/sprites/Items/swift_scarf/quick_bandana.png",
		"sprite_highlight": "res://assets/sprites/Items/swift_scarf/quick_bandana_highlight.png",
		"description": "Increases attack speed significantly"
	},
	"crystal_buckler": {
		"name": "Crystal Buckler",
		"rarity": "rare",
		"sprite_default": "res://assets/sprites/Items/crystal_buckler/crystal_scute.png",
		"sprite_highlight": "res://assets/sprites/Items/crystal_buckler/crystal_scute_highlight.png",
		"description": "Blocks 80% of next hit every 20s"
	}
	# Add more...
}

func on_player_hit_enemy(is_second_attack: bool):
	if not is_second_attack: 
		return

	# 3. Combo Board Logic
	if item_stacks.combo_board > 0:
		var max_buff_stacks = 3 + (item_stacks.combo_board - 1)
		combo_board_buff_stacks = clampi(combo_board_buff_stacks + 1, 0, max_buff_stacks)
		combo_board_timer = 4.0 # Reset/Start 4s timer
		print("Combo Board Stacks: ", combo_board_buff_stacks)

func get_combo_damage_modifier(is_second_attack: bool) -> float:
	var multiplier = 1.0
	# 8. Green Buge Logic
	if is_second_attack and item_stacks.green_buge > 0:
		multiplier += 0.5 + ((item_stacks.green_buge - 1) * 0.05)
	# 3. Combo Board Logic (Active Buff)
	if combo_board_buff_stacks > 0:
		multiplier += (combo_board_buff_stacks * 0.05)
	return multiplier
	
func get_combo_knockback_modifier(is_second_attack: bool) -> float:
	if is_second_attack and item_stacks.green_buge > 0:
		return 2.0 + ((item_stacks.green_buge - 1) * 0.05) # 100% + 5% per stack
	return 1.0
	
func on_enemy_died():
	if item_stacks.thick_root > 0:
		if player_node != null:
			# Logic: 5% of Max HP + 2% per extra stack
			var percent = 0.05 + ((item_stacks.thick_root - 1) * 0.02)
			var heal_amount = int(player_node.MAX_HEALTH * percent)
			player_node.heal(heal_amount)
	
func reset_game():
	inventory.clear()
	currency = 0
	player_stats = {
		"speed_bonus": 0, # %
		"damage_bonus": 0, # %
		"health_bonus": 0, # INT
		"crit_chance": 0, # %
		"damage_reduction": 0.0, # NEW: 0.0 to 1.0 (0% to 100%)
		"insta_kill_chance": 0.0, # %
		"attack_speed_multiplier": 1.0, # NEW: 1.0 is default
		"shield_active": false,
		"shield_cooldown_max": 20.0
	}
	item_stacks = {
		"speed_boots": 0,
		"precise_map": 0,
		"thick_root": 0,
		"combo_board": 0, # NEW
		"green_buge": 0,
		"protective_plushie": 0,
		"reality_eraser": 0, # NEW
		"swift_scarf": 0,
		"crystal_buckler": 0
	}
	print("GameManager reset.")
