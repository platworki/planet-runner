extends Area2D

var _hit_this_swing := {}
var _last_attack_id := -1
signal hit_enemy(enemy)

func _on_area_entered(area: Area2D) -> void:
	if owner.attack_id != _last_attack_id:
		_last_attack_id = owner.attack_id
		_hit_this_swing.clear()

	var enemy = null
	if area.has_meta("is_parry"):
		enemy = area.get_meta("entity")
		if enemy and enemy.has_method("trigger_parry_hit"):
			enemy.trigger_parry_hit()
			return

	if area.has_meta("entity"):
		enemy = area.get_meta("entity")
	else:
		enemy = area.get_parent()

	if not enemy or enemy.get("is_invincible"):
		return
	if enemy in _hit_this_swing:
		return

	if not enemy.get("is_boss"):
		var chance = GameManager.player_stats.insta_kill_chance
		if randf() * 100 < chance:
			if enemy.has_method("erase_from_reality"):
				enemy.erase_from_reality()
				print("REALITY ERASED!")
				return

	if enemy.has_method("take_damage"):
		var player = owner
		var is_second_attack = player.attack_hit_animation.current_animation == "Attack 2"

		var attack_result = player.get_current_attack_damage()
		var damage = attack_result["damage"]
		var crit = attack_result["is_crit"]
		var bleed_modifier = GameManager.get_bleed_damage_modifier(enemy)
		damage = int(damage * bleed_modifier)

		var kb_multiplier = GameManager.get_combo_knockback_modifier(is_second_attack)

		_hit_this_swing[enemy] = true  # mark this enemy hit for this swing

		GameManager.on_player_hit_enemy(is_second_attack, enemy)
		emit_signal("hit_enemy", enemy)
		if crit:
			Effects.play_screen_flash(1, 0.65, 0.65, 0.3, 0.2)

		enemy.take_damage(damage, player.global_position, kb_multiplier)
