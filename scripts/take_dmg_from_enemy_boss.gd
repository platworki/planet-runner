extends Area2D

@onready var damage_timer: Timer = $DamageIfInside
var player_inside = null

func _on_body_entered(body: Node) -> void:
	if not body.has_method("take_damage"):
		return
	
	# INFO Save the body node that entered the hitbox
	player_inside = body

	# INFO Deal the damage
	var enemy = get_parent().get_parent()
	body.take_damage(enemy.DAMAGE, enemy.global_position)

	# INFO Start the damage timer once the player enters
	damage_timer.start()

func _on_body_exited(body: Node) -> void:
	# INFO If the body that left is the same body as the body that entered,
	# reset and stop dealing damage
	if body == player_inside:
		player_inside = null
		damage_timer.stop()

func _on_damage_timer_timeout() -> void:
	# INFO Keep dealing damage every 0.3 seconds if player_inside is still
	# the body and it has a take_damage method
	if player_inside and player_inside.has_method("take_damage"):
		var enemy = get_parent().get_parent().get_parent()
		player_inside.take_damage(enemy.DAMAGE, enemy.global_position)
	else:
		damage_timer.stop()
