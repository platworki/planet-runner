extends Node

signal stats_changed
# Inventory storage
var inventory = []
var currency = 0
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
	"shield_cooldown_max": 20.0,
	"karma_stacks": 0,
	"karma_healing": 0.5,
	"dash_boost": 0,
	"bleed_chance": 0.0,
	"poison_chance": 0.0,
	"slow_chance": 0.0,
	"burn_chance": 0.0,
	"jump_multiplier": 1.0,
	"explosion_chance": 0.0
}

const MAX_STACKS = {
	"speed_boots": 5,
	"precise_map": 5,
	"thick_root": 5,
	"combo_board": 5,
	"green_buge": 5,
	"protective_plushie": 5,
	"reality_eraser": 5,
	"swift_scarf": 5,
	"crystal_buckler": 5,
	"power_fruit": 5,
	"karma_flower": 5,
	"wind_turbine": 5,
	"particle_accelerator": 5,
	"blood_hammer": 5,
	"sticky_stone": 5,
	"flammable_keg": 5,
	"edge_sharpener": 5,
	"uranium_gel": 5,
	"booster_jets": 5,
	"squeaky_mallet": 5
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
	"crystal_buckler": 0,
	"power_fruit": 0,
	"karma_flower": 0,
	"wind_turbine": 0,
	"particle_accelerator": 0,
	"blood_hammer": 0,
	"sticky_stone": 0,
	"flammable_keg": 0,
	"edge_sharpener": 0,
	"uranium_gel": 0,
	"booster_jets": 0,
	"squeaky_mallet": 0
}

var status_effects_info = {
	"bleed": {
		"damage_per_tick": 2,
		"duration": 2.5, #in seconds
		"effect_animation": "bleed_animation",
		"max_stacks": 999
	},
	"burn": {
		"damage_per_tick": 1,
		"duration": 5.5, #in seconds
		"effect_animation": "burn_animation",
		"max_stacks": 1
	},
	"poison": {
		"damage_per_tick": 0.01, #this is a percentage
		"duration": 4, #in seconds
		"effect_animation": "poison_animation",
		"max_stacks": 3 # add a green modulate when 3 stacks apply
	},
	"slow": {
		"damage_per_tick": 0,
		"duration": 3, #in seconds
		"effect_animation": "slow_animation",
		"max_stacks": 1
	}
}

var combo_board_timer = 0.0
var buckler_timer = 0.0

func _process(delta: float) -> void:
	if player_node:
		if player_stats.shield_active:
			player_node.shield_animation.visible = true
		else:
			player_node.shield_animation.visible = false
	
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
	
	var popup = get_tree().get_first_node_in_group("ItemPopup")
	if popup:
		popup.display_item(item_data)
	
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
		"power_fruit":
			player_stats.health_bonus = 20 + ((item_stacks.power_fruit - 1) * 10)
		"karma_flower":
			player_stats.karma_stacks += 1
			player_stats.karma_healing = 0.4 + (0.1 *(item_stacks.karma_flower - 1))
		"wind_turbine":
			player_stats.dash_boost += 22
		"particle_accelerator":
			player_stats.dash_boost += 40
		"protective_plushie":
			# 5% base + 3% per extra stack
			player_stats.damage_reduction = 0.10 + ((item_stacks.protective_plushie - 1) * 0.07)
		"reality_eraser":
			# 3% base + 1% per extra stack
			player_stats.insta_kill_chance = 3.0 + ((item_stacks.reality_eraser - 1) * 2.0)
		"swift_scarf":
			# 5% base + 5% per extra stack
			# Stack 1: 1.05 | Stack 5: 1.25 (25% faster)
			player_stats.attack_speed_multiplier = 1.00 + (item_stacks.swift_scarf * 0.15)
		"crystal_buckler":
			# 20s -> 18s -> 16.2s etc.
			player_stats.shield_cooldown_max = 20.0 * pow(0.9, item_stacks.crystal_buckler - 1)
			# If they just bought it, start the timer
			if not player_stats.shield_active and buckler_timer <= 0:
				buckler_timer = player_stats.shield_cooldown_max
		"blood_hammer":
			player_stats.bleed_chance = 0.1 * item_stacks.edge_sharpener + 0.2 * item_stacks.blood_hammer
		"sticky_stone":
			player_stats.slow_chance += 0.15
		"flammable_keg":
			player_stats.explosion_chance += 0.20
		"edge_sharpener":
			player_stats.bleed_chance = 0.1 * item_stacks.edge_sharpener + 0.2 * item_stacks.blood_hammer
		"uranium_gel":
			player_stats.poison_chance += 0.1
			player_stats.burn_chance += 0.08
		"booster_jets":
			player_stats.jump_multiplier = 1.15 + ((item_stacks.booster_jets - 1) * 0.1)
		"squeaky_mallet":
			pass

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
	
func get_bleed_damage_modifier(enemy) -> float:
	if item_stacks.blood_hammer <= 0:
		return 1.0
	if not enemy.get("active_effects"):
		return 1.0
	if not "bleed" in enemy.active_effects:
		return 1.0
	# +20% per stack, e.g. stack 1 = 1.2x, stack 5 = 2.0x
	print("POBRANO BLOOD HAMMER MODIFIER")
	return 1.0 + (item_stacks.blood_hammer * 0.40)
	
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
		"rarity": "common",
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
		"rarity": "common",
		"sprite_default": "res://assets/sprites/Items/combo_board/suspicious_scoreboard.png",
		"sprite_highlight": "res://assets/sprites/Items/combo_board/suspicious_scoreboard_highlight.png",
		"description": "2nd hit grants damage buff"
	},
	"green_buge": {
		"name": "Green Buge",
		"rarity": "super_rare",
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
		"rarity": "common",
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
	},
	"power_fruit": {
		"name": "Power Fruit",
		"rarity": "common",
		"sprite_default": "res://assets/sprites/Items/funky_fruit/power_pumpkin.png",
		"sprite_highlight": "res://assets/sprites/Items/funky_fruit/power_pumpkin_highlight.png",
		"description": "Increases base player health"
	},
	"karma_flower": {
		"name": "Karma Flower",
		"rarity": "rare",
		"sprite_default": "res://assets/sprites/Items/revival_bloom/revive_flower.png",
		"sprite_highlight": "res://assets/sprites/Items/revival_bloom/revive_flower_highlight.png",
		"description": "Heals when low HP, once per stage"
	},
	"wind_turbine": {
		"name": "Retro Turbine",
		"rarity": "rare",
		"sprite_default": "res://assets/sprites/Items/wind_dynamo/wind_generator.png",
		"sprite_highlight": "res://assets/sprites/Items/wind_dynamo/wind_generator_highlight.png",
		"description": "Improves dash speed"
	},
	"particle_accelerator": {
		"name": "Particle Accelerator",
		"rarity": "super_rare",
		"sprite_default": "res://assets/sprites/Items/particle_accelerator/prtcl_accelerator.png",
		"sprite_highlight": "res://assets/sprites/Items/particle_accelerator/prtcl_accelerator_highlight.png",
		"description": "Dashing is improved and gives invincibility"
	},
	"blood_hammer": {
	"name": "Blood Hammer",
	"rarity": "super_rare",
	"sprite_default": "res://assets/sprites/Items/blood_hammer/bld_hammer_sprite.png",
	"sprite_highlight": "res://assets/sprites/Items/blood_hammer/bld_hammer_highlight.png",
	"description": "Deal bonus damage to bleeding enemies, increases bleed chance"
	},
	"sticky_stone": {
	"name": "Sticky Stone",
	"rarity": "rare",
	"sprite_default": "res://assets/sprites/Items/goo_stone/goo_rock_sprite.png",
	"sprite_highlight": "res://assets/sprites/Items/goo_stone/goo_rock_highlight.png",
	"description": "+15% chance to slow enemies"
	},
	"flammable_keg": {
		"name": "Flammable Keg",
		"rarity": "common",
		"sprite_default": "res://assets/sprites/Items/flammable_keg/oil_sprite.png",
		"sprite_highlight": "res://assets/sprites/Items/flammable_keg/oil_highlight.png",
		"description": "+15% chance to explode on taking dmg"
	},
	"edge_sharpener": {
		"name": "Edge Sharpener",
		"rarity": "common",
		"sprite_default": "res://assets/sprites/Items/weapon_sharpener/sharp_sprite.png",
		"sprite_highlight": "res://assets/sprites/Items/weapon_sharpener/sharp_highlight.png",
		"description": "+10% chance to bleed enemies"
	},
	"uranium_gel": {
		"name": "Uranium Gel",
		"rarity": "rare",
		"sprite_default": "res://assets/sprites/Items/uranium_jelly/uranium_jelly.png",
		"sprite_highlight": "res://assets/sprites/Items/uranium_jelly/uranium_jelly_highlight.png",
		"description": "+8% chance to burn and poison enemies"
	},
	"booster_jets": {
		"name": "Booster Jets",
		"rarity": "rare",
		"sprite_default": "res://assets/sprites/Items/jump_pack/jump_pack.png",
		"sprite_highlight": "res://assets/sprites/Items/jump_pack/jump_pack_highlight.png",
		"description": "Improves double jump height"
	},
	"squeaky_mallet": {
		"name": "Squeaky Mallet",
		"rarity": "super_rare",
		"sprite_default": "res://assets/sprites/Items/squeaky_mallet/squeaky_mallet.png",
		"sprite_highlight": "res://assets/sprites/Items/squeaky_mallet/squeaky_mallet_highlight.png",
		"description": "first attack slows enemies, increases knockback of 2nd attack"
	}
	# Add more...
}

func on_player_hit_enemy(is_second_attack: bool, enemy):
	# Squeaky Mallet - pierwszy hit nakłada slow
	if not is_second_attack:
		if item_stacks.squeaky_mallet > 0:
			if enemy.has_method("apply_status_effect"):
				enemy.apply_status_effect("slow")
				print("Squeaky Mallet: pierwszy hit - SLOW!")
		return

	# Combo Board
	if item_stacks.combo_board > 0:
		var max_buff_stacks = 3 + (item_stacks.combo_board - 1)
		combo_board_buff_stacks = clampi(
			combo_board_buff_stacks + 1,
			0,
			max_buff_stacks
		)
		combo_board_timer = 4.0
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
	if not is_second_attack:
		return 1.0
	
	var multiplier = 1.0
	
	# Green Buge
	if item_stacks.green_buge > 0:
		multiplier *= 2.0 + ((item_stacks.green_buge - 1) * 0.05)
	
	# Squeaky Mallet
	if item_stacks.squeaky_mallet > 0:
		multiplier *= 1.5 + ((item_stacks.squeaky_mallet - 1) * 0.25)
	
	return multiplier
	
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
		"shield_cooldown_max": 20.0,
		"karma_stacks": 0,
		"karma_healing": 0.5,
		"dash_boost": 0,
		"bleed_chance": 0.0,
		"poison_chance": 0.0,
		"slow_chance": 0.0,
		"burn_chance": 0.0,
		"jump_multiplier": 1.0,
		"explosion_chance": 0.0
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
		"crystal_buckler": 0,
		"power_fruit": 0,
		"karma_flower": 0,
		"wind_turbine": 0,
		"particle_accelerator": 0,
		"blood_hammer": 0,
		"sticky_stone": 0,
		"flammable_keg": 0,
		"edge_sharpener": 0,
		"uranium_gel": 0,
		"booster_jets": 0,
		"squeaky_mallet": 0
	}
	print("GameManager reset.")
