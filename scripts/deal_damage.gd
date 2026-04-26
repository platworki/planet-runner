extends Area2D

signal hit_enemy(enemy)

func _on_area_entered(area: Area2D) -> void:
	# Check if we hit an enemy hitbox
	var enemy = area.get_parent()  # Get the slime
	if enemy.is_invincible:
		return

	# NEW: Reality Eraser Logic
	if enemy.has_method("die") and not enemy.is_boss:
		var roll = randf() * 100
		if roll < GameManager.player_stats.insta_kill_chance:
			print("REALITY ERASED!")
			enemy.die() # Trigger enemy death immediately
			return # Skip normal damage calculation

	if enemy.has_method("take_damage"):
		var player = get_parent().get_parent()
		
		var is_second_attack = player.attack_hit_animation.current_animation == "Attack 2"
		# Tell GameManager a hit happened (triggers Combo Board)
		GameManager.on_player_hit_enemy(is_second_attack)
		# Get player's damage value
		# tell the player (or whoever's connected) that we hit an enemy
		emit_signal("hit_enemy", enemy)
		
		var damage = player.get_current_attack_damage()
		var kb_multiplier = GameManager.get_combo_knockback_modifier(is_second_attack)
		
		enemy.take_damage(damage, player.global_position, kb_multiplier)
