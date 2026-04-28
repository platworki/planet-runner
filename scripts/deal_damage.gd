extends Area2D

signal hit_enemy(enemy)

func _on_area_entered(area: Area2D) -> void:
	var enemy = null
	
	if area.has_meta("is_parry"):
		enemy = area.get_meta("entity")
		if enemy and enemy.has_method("trigger_parry_hit"):
			enemy.trigger_parry_hit()
			return # IMPORTANT: Stop everything else so we don't deal damage

	if area.has_meta("entity"):
		enemy = area.get_meta("entity")
	else:
		enemy = area.get_parent()
		
	# Safety check for area/enemy existence
	if not enemy or enemy.get("is_invincible"):
		return
		
	if not enemy.get("is_boss"): # Safety: Don't erase bosses!
			var chance = GameManager.player_stats.insta_kill_chance
			if randf() * 100 < chance:
				if enemy.has_method("erase_from_reality"):
					enemy.erase_from_reality()
					print("REALITY ERASED!")
					return # Skip normal damage if erased	
		
	if enemy.has_method("take_damage"):
		var player = get_parent().get_parent()
		
		var is_second_attack = player.attack_hit_animation.current_animation == "Attack 2"
		# Tell GameManager a hit happened (triggers Combo Board)
		GameManager.on_player_hit_enemy(is_second_attack)
		# Get player's damage value
		# tell the player that we hit an enemy
		emit_signal("hit_enemy", enemy)
		
		var damage = player.get_current_attack_damage()
		var kb_multiplier = GameManager.get_combo_knockback_modifier(is_second_attack)
		
		enemy.take_damage(damage, player.global_position, kb_multiplier)
