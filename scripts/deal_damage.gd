extends Area2D

signal hit_enemy(enemy)

func _on_area_entered(area: Area2D) -> void:
	# Check if we hit an enemy hitbox
	var enemy = area.get_parent()  # Get the slime
	if enemy.is_invincible:
		return
	if enemy.has_method("take_damage"):
		# Get player's damage value
		var player = get_parent().get_parent()  # Position -> Player
		# tell the player (or whoever's connected) that we hit an enemy
		emit_signal("hit_enemy", enemy)
		
		var damage = player.get_current_attack_damage()
		enemy.take_damage(damage, player.global_position)
