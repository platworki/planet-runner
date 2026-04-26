extends Area2D

@onready var melee_hitbox: CollisionShape2D = $"../MeleeArea/MeleeHitbox"

# This script lives on the MeleeRadius node
func _physics_process(_delta: float) -> void:
	# Only do this if the collision shape is actually active
	if not melee_hitbox.disabled:
		var bodies = get_overlapping_bodies()
		for body in bodies:
			if body.name == "Player" and body.has_method("take_damage"):
				# Access the Helicopter's LASER_DAMAGE specifically
				var fireElemental = get_parent()
				body.take_damage(fireElemental.MELEE_DAMAGE, fireElemental.global_position)
				# Optional: Turn off the hitbox immediately so it doesn't 
				# hit the player 60 times per second
				melee_hitbox.set_deferred("disabled", true)
