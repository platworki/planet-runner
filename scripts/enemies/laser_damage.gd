extends Area2D

# This script lives on the AttackRadius node
func _physics_process(_delta: float) -> void:
	# Only do this if the collision shape is actually active
	if not $LaserCollision.disabled:
		var bodies = get_overlapping_bodies()
		for body in bodies:
			if body.name == "Player" and body.has_method("take_damage"):
				# Access the Helicopter's LASER_DAMAGE specifically
				var heli = get_parent()
				body.take_damage(heli.LASER_DAMAGE, heli.global_position)
				
				# Optional: Turn off the hitbox immediately so it doesn't 
				# hit the player 60 times per second
				$LaserCollision.set_deferred("disabled", true)
