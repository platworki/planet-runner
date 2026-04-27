extends Area2D

@onready var parry_hitbox: CollisionShape2D = $ParryHitbox

func _physics_process(_delta: float) -> void:
	if not parry_hitbox.disabled:
		var bodies = get_overlapping_bodies()
		for body in bodies:
			if body.name == "Player" and body.has_method("take_damage"):
				# Access the Helicopter's LASER_DAMAGE specifically
				var snek = get_parent().get_parent()
				body.take_damage(snek.PARRY_DAMAGE, snek.global_position)
				parry_hitbox.set_deferred("disabled", true)
