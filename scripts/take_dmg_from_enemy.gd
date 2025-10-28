extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		var enemy = get_parent()  # The slime itself (CharacterBody2D)
		body.take_damage(enemy.DAMAGE, enemy.global_position)
